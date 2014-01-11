unit MainForm;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, TLHelp32, ShellAPI, UsbClass;

type
  TfrmAppleMouse= class(TForm)
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
  private
    {Private declarations}
    FUsb: TUsbClass;
  public
    {Public declarations}
    procedure UsbChangeEvent(const bInserted: boolean; const ADevType, ADriverName, AFriendlyName: string);
    procedure OnAttachMouse;
    procedure OnDetachMouse;
  end;

var
  frmAppleMouse: TfrmAppleMouse;

implementation

{$R *.dfm}

function GetProcessIDFromName(ProcessName: String): Dword;
var
  ContinueLoop: BOOL;
  FSnapshotHandle: THandle;
  FProcessEntry32: TProcessEntry32;
begin
  Result:=0;
  FSnapshotHandle:=CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  FProcessEntry32.dwSize:=SizeOf(FProcessEntry32);
  ContinueLoop:=Process32First(FSnapshotHandle, FProcessEntry32);
  while Integer(ContinueLoop)<>0 do
  begin
    if (UpperCase(ExtractFileName(FProcessEntry32.szExeFile))=UpperCase(ProcessName))or(UpperCase(FProcessEntry32.szExeFile)=UpperCase(ProcessName)) then
    begin
      Result:=FProcessEntry32.th32ProcessID;
      Break;
    end;
    ContinueLoop:=Process32Next(FSnapshotHandle, FProcessEntry32);
  end;
  CloseHandle(FSnapshotHandle);
end;

function GetDosOutput(ExecuteCommand: string): string;
var
  SA: TSecurityAttributes;
  SI: TStartupInfo;
  PI: TProcessInformation;
  StdOutPipeRead, StdOutPipeWrite: THandle;
  WasOK: boolean;
  Buffer: array [0..255] of AnsiChar;
  BytesRead: Cardinal;
  Handle: boolean;
begin
  Result:='';
  with SA do
  begin
    nLength:=SizeOf(SA);
    bInheritHandle:=True;
    lpSecurityDescriptor:=nil;
  end;
  CreatePipe(StdOutPipeRead, StdOutPipeWrite, @SA, 0);
  try
    with SI do
    begin
      FillChar(SI, SizeOf(SI), 0);
      cb:=SizeOf(SI);
      dwFlags:=STARTF_USESHOWWINDOW or STARTF_USESTDHANDLES;
      wShowWindow:=SW_HIDE;
      hStdInput:=GetStdHandle(STD_INPUT_HANDLE);
      hStdOutput:=StdOutPipeWrite;
      hStdError:=StdOutPipeWrite;
    end;
    Handle:=CreateProcess(nil, PChar('cmd.exe /C '+ExecuteCommand), nil, nil, True, 0, nil, PChar(ExtractFilePath(ExecuteCommand)), SI, PI);
    CloseHandle(StdOutPipeWrite);
    if Handle then
      try
        repeat
          WasOK:=ReadFile(StdOutPipeRead, Buffer, 255, BytesRead, nil);
          if BytesRead>0 then
          begin
            Buffer[BytesRead]:=#0;
            Result:=Result+String(Buffer);
          end;
        until not WasOK or(BytesRead=0);
        WaitForSingleObject(PI.hProcess, INFINITE);
      finally
        CloseHandle(PI.hThread);
        CloseHandle(PI.hProcess);
      end;
  finally
    CloseHandle(StdOutPipeRead);
  end;
end;

procedure TfrmAppleMouse.FormCreate(Sender: TObject);
var
  MouseData: String;
begin
  FUsb:=TUsbClass.Create;
  FUsb.OnUsbChange:=UsbChangeEvent;
  {* Wait For Explorer.exe *}
  while GetProcessIDFromName('explorer.exe')=0 do
    Sleep(100);
  {* Check For Mouse Plugged In *}
  MouseData:=GetDosOutput(ExtractFilePath(Application.ExeName)+'\devcon.exe hwids *mouse*');
  if pos('3 matching device(s) found.', MouseData)>0 then
    OnAttachMouse
  else
    OnDetachMouse;
end;

procedure TfrmAppleMouse.FormDestroy(Sender: TObject);
begin
  FUsb.Free;
end;

procedure TfrmAppleMouse.OnAttachMouse;
var
  hAppleHandle: THandle;
begin
  {* Disable Trackpad *}
  ShellExecute(0, 'open', PChar(ExtractFilePath(Application.ExeName)+'\devcon.exe'), 'disable "*MI_01&Col01*"', nil, 0);
  {* Disable Reverse Scrolling *}
  hAppleHandle:=OpenProcess(PROCESS_TERMINATE, False, GetProcessIDFromName('AppleMouseReverse.exe'));
  TerminateProcess(hAppleHandle, 0);
  CloseHandle(hAppleHandle);
end;

procedure TfrmAppleMouse.OnDetachMouse;
begin
  {* Enable Trackpad *}
  ShellExecute(0, 'open', PChar(ExtractFilePath(Application.ExeName)+'\devcon.exe'), 'enable "*MI_01&Col01*"', nil, 0);
  {* Enable Reverse Scrolling *}
  if GetProcessIDFromName('AppleMouseReverse.exe')=0 then
    ShellExecute(0, 'open', PChar(ExtractFilePath(Application.ExeName)+'\AppleMouseReverse.exe'), nil, nil, 0);
end;

procedure TfrmAppleMouse.UsbChangeEvent(const bInserted: boolean; const ADevType, ADriverName, AFriendlyName: string);
begin
  OutputDebugString(PChar(ADevType+ADriverName+AFriendlyName));
  if (pos('USB MOUSE', UpperCase(ADevType))>0)or(pos('USB INPUT', UpperCase(ADevType))>0) then
  begin
    if bInserted then
    begin
      OnAttachMouse;
      Exit;
    end
    else
    begin
      OnDetachMouse;
      Exit;
    end;
  end;
end;

end.
