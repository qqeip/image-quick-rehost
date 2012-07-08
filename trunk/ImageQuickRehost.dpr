program ImageQuickRehost;

uses
  Vcl.Forms,
  UntMain in 'UntMain.pas' {frmMain};

{$R *.res}

begin

  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.
