program PerseveranceFMX;

uses
  System.StartUpCopy,
  FMX.Forms,
  Perseverance.FMX.Main in 'Perseverance.FMX.Main.pas' {MainForm},
  Execute.GLB.FMX in '..\lib\Execute.GLB.FMX.pas',
  Execute.GLB in '..\lib\Execute.GLB.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
