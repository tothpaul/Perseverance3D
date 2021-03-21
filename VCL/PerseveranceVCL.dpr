program PerseveranceVCL;

uses
  Vcl.Forms,
  Perseverance.VCL.Main in 'Perseverance.VCL.Main.pas' {Main},
  Execute.GLB in '..\lib\Execute.GLB.pas',
  Execute.GLPanel in '..\lib\Execute.GLPanel.pas' {GLPanel: TFrame},
  Execute.GLB.OpenGL in '..\lib\Execute.GLB.OpenGL.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TMain, Main);
  Application.Run;
end.
