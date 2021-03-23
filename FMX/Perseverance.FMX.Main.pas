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
    TreeView1: TTreeView;
    Layout2: TLayout;
    Layout3: TLayout;
    Label1: TLabel;
    Edit1: TEdit;
    Label2: TLabel;
    Edit2: TEdit;
    Label3: TLabel;
    Edit3: TEdit;
    procedure btGoClick(Sender: TObject);
    procedure Viewport3D1MouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Single);
    procedure Viewport3D1MouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Single);
    procedure Viewport3D1MouseWheel(Sender: TObject; Shift: TShiftState;
      WheelDelta: Integer; var Handled: Boolean);
    procedure FormCreate(Sender: TObject);
    procedure TreeView1Click(Sender: TObject);
  private
    { Déclarations privées }
    FDown: TPointF;
    FModel: TGLBFMXModel;
    FMesh: TMesh;
    FMat: TMaterialSource;
    procedure BuildTree(Parent: TTreeViewItem; Obj: TFmxObject);
  public
    { Déclarations publiques }
  end;

var
  MainForm: TMainForm;

implementation

{$R *.fmx}

procedure TMainForm.BuildTree(Parent: TTreeViewItem; Obj: TFmxObject);
var
  LIndex: Integer;
  LChild: TTreeViewItem;
begin
  if Parent = nil then
  begin
    Parent := TTreeViewItem.Create(Self);
    Parent.Text := 'root';
    Parent.TagObject := Obj;
    TreeView1.AddObject(Parent);
  end;
  for LIndex := 0 to Obj.ChildrenCount - 1 do
  begin
    LChild := TTreeViewItem.Create(Self);
    LChild.Parent := Parent;
    LChild.Text := Obj.Children[LIndex].ClassName;
    LChild.TagObject := Obj.Children[LIndex];
    BuildTree(LChild, Obj.Children[LIndex]);
  end;
end;

procedure TMainForm.FormCreate(Sender: TObject);
begin
  FModel := TGLBFMXModel.Create(Self);
  FModel.Parent := root;
end;

procedure TMainForm.TreeView1Click(Sender: TObject);
begin
  if FMesh <> nil then
  begin
    FMesh.MaterialSource := FMat;
  end;
  if TreeView1.Selected.TagObject is TMesh then
  begin
    FMesh := TMesh(TreeView1.Selected.TagObject);
    FMat := FMesh.MaterialSource;
    FMesh.MaterialSource := nil;
  end else begin
    FMesh := nil;
  end;
  if TreeView1.Selected.TagObject is TControl3D then
  begin
    with TControl3D(TreeView1.Selected.TagObject) do
    begin
      Edit1.Text := Position.X.ToString + '/' + Position.Y.ToString + '/' + Position.Z.ToString;
      Edit2.Text := RotationAngle.X.ToString + '/' + RotationAngle.Y.ToString + '/' + RotationAngle.Z.ToString;
      Edit3.Text := Scale.X.ToString + '/' + Scale.Y.ToString + '/' + Scale.Z.ToString;
    end;
  end;
  ViewPort3D1.Repaint;
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
    TreeView1.Clear;
    BuildTree(nil, FModel);
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
end;

procedure TMainForm.Viewport3D1MouseWheel(Sender: TObject; Shift: TShiftState;
  WheelDelta: Integer; var Handled: Boolean);
begin
  root.Position.Z := root.Position.Z - ((WheelDelta / 120) * 0.3);
end;

end.
