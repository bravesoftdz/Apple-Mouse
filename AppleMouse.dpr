program AppleMouse;

uses
  Forms,
  MainForm in 'MainForm.pas' {frmAppleMouse},
  UsbClass in 'UsbClass.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar:=True;
  Application.ShowMainForm:=False;
  Application.CreateForm(TfrmAppleMouse, frmAppleMouse);
  Application.Run;

end.
