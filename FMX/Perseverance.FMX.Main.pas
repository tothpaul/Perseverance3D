unit Perseverance.FMX.Main;

interface

uses
  System.SysUtils,
  System.Types,
  System.UITypes,
  System.Classes,
  System.Variants,
  System.JSON,
  FMX.Types,
  FMX.Controls,
  FMX.Forms,
  FMX.Graphics,
  FMX.Dialogs,
  FMX.StdCtrls,
  FMX.Controls.Presentation,
  FMX.Edit,
  FMX.Objects,
  FMX.Layouts,
  FMX.Types3D,
  System.Net.URLClient,
  System.Net.HttpClient,
  System.Net.HttpClientComponent,
  System.IOUtils,
  System.Math.Vectors,
  FMX.Controls3D,
  FMX.Objects3D,
  FMX.Viewport3D,
  FMX.MaterialSources,
  Execute.GLB.FMX, FMX.TreeView;

type
  TMainForm = class(TForm)
    Layout1: TLayout;
    Text1: TText;
    edURL: TEdit;
    btGo: TButton;
    NetHTTPClient: TNetHTTPClient;
    Viewport3D1: TViewport3D;
    Light1: TLight;
    root: TDummy;
    procedure btGoClick(Sender: TObject);
    procedure Viewport3D1MouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Single);
    procedure Viewport3D1MouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Single);
    procedure Viewport3D1MouseWheel(Sender: TObject; Shift: TShiftState;
      WheelDelta: Integer; var Handled: Boolean);
    procedure FormCreate(Sender: TObject);
  private
    { Déclarations privées }
    FDown: TPointF;
    FModel: TGLBFMXModel;
    FMesh: TMesh;
    FMat: TMaterialSource;
  public
    { Déclarations publiques }
  end;

var
  MainForm: TMainForm;

implementation

{$R *.fmx}

procedure TMainForm.FormCreate(Sender: TObject);
//var
//  Stream: TFileStream;
begin
  FModel := TGLBFMXModel.Create(Self);
  FModel.Parent := root;

//  Stream := TFileStream.Create('..\..\..\VCL\win32\debug\TEST.GLB', fmOpenRead);
//  FModel.LoadFromStream(Stream);
//  Stream.Free;
end;

procedure TMainForm.btGoClick(Sender: TObject);
var
  GLB: TMemoryStream;
begin
  GLB := TMemoryStream.Create;
  try
  {$IFDEF DEBUG}
    if FileExists('Perseverance.glb') then
    begin
      GLB.LoadFromFile('Perseverance.glb');
    end else begin
  {$ENDIF}
    NetHTTPClient.Get(edURL.Text, GLB);
  {$IFDEF DEBUG}
      GLB.SaveToFile('Perseverance.glb')
    end;
  {$ENDIF}
    GLB.Position := 0;
    FModel.LoadFromStream(GLB);
  finally
    GLB.Free;
  end;
end;

procedure TMainForm.Viewport3D1MouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Single);
begin
  FDown := PointF(X, Y);
end;

procedure TMainForm.Viewport3D1MouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Single);
begin
  if (ssLeft in Shift) then
  begin
    root.RotationAngle.X := root.RotationAngle.X + (Y - FDown.Y) * 0.3;
    root.RotationAngle.Y := root.RotationAngle.Y + (X - FDown.X) * 0.3;
    FDown.X := X;
    FDown.Y := Y;
  end;
  if (ssRight in Shift) then
  begin
    root.Position.Z := root.Position.Z - (Y - FDown.Y) * 0.3;
    FDown.Y := Y;
  end;
end;

procedure TMainForm.Viewport3D1MouseWheel(Sender: TObject; Shift: TShiftState;
  WheelDelta: Integer; var Handled: Boolean);
begin
  root.Position.Z := root.Position.Z - ((WheelDelta / 120) * 0.3);
end;

end.
