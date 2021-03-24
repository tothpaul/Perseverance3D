unit Perseverance.VCL.Main;
{
  Perseverance GLB Viewer for Delphi Sydney (c)2011 Execute SARL <contact@execute.fr>
}
interface

uses
  Winapi.Windows,
  Winapi.Messages,
  Winapi.OpenGL,
  Winapi.OpenGLext,
  System.Types,
  System.SysUtils,
  System.Variants,
  System.Classes,
  System.Net.HttpClient,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Dialogs,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  System.Net.URLClient,
  System.Net.HttpClientComponent,
  Execute.GLB,
  Execute.GLB.OpenGL,
  Execute.GLPanel,
  Execute.GLBBuilder;

type
  TMain = class(TForm)
    Panel1: TPanel;
    edURL: TEdit;
    Label1: TLabel;
    btGo: TButton;
    NetHTTPClient: TNetHTTPClient;
    GLPanel: TGLPanel;
    Timer1: TTimer;
    procedure btGoClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure GLPanelMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure GLPanelMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure GLPanelMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure Timer1Timer(Sender: TObject);
  private
    { Déclarations privées }
    Model: TGLBOpenGLModel;
    Matrix: TMatrix;
    Mouse: TPoint;
    Down: Boolean;
    rx, ry, rz, tz: Integer;
    Start: Cardinal;
    MultiFormat: Integer;
    procedure GLSetup(Sender: TObject);
    procedure GLPaint(Sender: TObject);
  public
    { Déclarations publiques }
  end;

var
  Main: TMain;

implementation

{$R *.dfm}

procedure TMain.FormCreate(Sender: TObject);
//var
//  Builder: TGLBBuilder;
//  Prim: TGLBBuilderPrimitive;
//  Mesh: TGLBBuilderMesh;
//  Node: TGLBBuilderNode;
//  Child: TGLBBuilderNode;
//  Stream: TFileStream;
begin
  Model := TGLBOpenGLModel.Create;
  GLPanel.OnSetup := GLSetup;
  GLPanel.OnPaint := GLPaint;

// the code below was used to compare VCL with OpenGL and FMX version on a simple model
// -> the Mesh WrapMode must be Original !
// -> the Axis need to be reoriented (Scale < 0)
// -> the Quaternion need a custom code


//  Builder := TGLBBuilder.Create;
//
//  Prim := TGLBBuilderPrimitive.Create;
//  Prim.AddPoint(-1, -1, 0);
//  Prim.AddNormal(0, 0, 1);
//  Prim.AddPoint(+1, -1, 0);
//  Prim.AddNormal(0, 0, 1);
//  Prim.AddPoint(-1, +1, 0);
//  Prim.AddNormal(0, 0, 1);
//  Prim.AddFace(0, 1, 2);
//
//  Mesh := Builder.AddMesh(Prim);
//  Mesh.Material := Builder.AddMaterialColor($FFFF0000);
//  Node := Builder.AddNode(True);
//  Node.Mesh := Mesh;
//
//  Mesh := Builder.AddMesh(Prim);
//  Mesh.Material := Builder.AddMaterialColor($FF00FF00);
//  Child := Builder.AddNode(False);
//  Child.Translate(0, 0, 2);
//  Child.Mesh := Mesh;
//  Node.AddNode(Child);
//
//  Mesh := Builder.AddMesh(Prim);
//  Mesh.Material := Builder.AddMaterialColor($FFFFFF00);
//  Child := Builder.AddNode(False);
//  Child.Translate(2, 0, 0);
//  Child.Mesh := Mesh;
//  Node.AddNode(Child);
//
//  Mesh := Builder.AddMesh(Prim);
//  Mesh.Material := Builder.AddMaterialColor($FF0000FF);
//  Child := Builder.AddNode(False);
//  Child.Translate(0, 2, 0);
//  Child.Mesh := Mesh;
//  Node.AddNode(Child);
//
//  Mesh := Builder.AddMesh(Prim);
//  Mesh.Material := Builder.AddMaterialColor($FFFF00FF);
//  Child := Builder.AddNode(False);
//  Child.Translate(-2, 0, 0);
//  Child.Rotate(0.707, 0.707, 0, 0); // X - 90°   https://quaternions.online/
//  Child.Mesh := Mesh;
//  Node.AddNode(Child);
//
//  Mesh := Builder.AddMesh(Prim);
//  Mesh.Material := Builder.AddMaterialColor($FF00FFFF);
//  Child := Builder.AddNode(False);
//  Child.Translate(-1, 0, +1);
//  Child.Rotate(0.707, 0, 0.707, 0); // Y - 90°
//  Child.Mesh := Mesh;
//  Node.AddNode(Child);
//
//  Mesh := Builder.AddMesh(Prim);
//  Mesh.Material := Builder.AddMaterialColor($FF808080);
//  Child := Builder.AddNode(False);
//  Child.Translate(0, -1, +1);
//  Child.Rotate(0.707, 0, 0, 0.707); // Z - 90°
//  Child.Mesh := Mesh;
//  Node.AddNode(Child);
//
//  Builder.SaveToFile('TEST.GLB');
//  Builder.Free;
//  Stream := TFileStream.Create('TEST.GLB', fmOpenRead);
//  Model.LoadFromStream(Stream);
//  Stream.Free;
end;

procedure TMain.FormDestroy(Sender: TObject);
begin
  Model.Free;
end;

procedure TMain.GLSetup(Sender: TObject);
begin
  glGetFloatV(GL_MODELVIEW_MATRIX, @Matrix);
  glDisable(GL_CULL_FACE);
  glEnable(GL_NORMALIZE);
  Start := GetTickCount;
end;

procedure TMain.btGoClick(Sender: TObject);
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
    Model.Clear;
    Model.LoadFromStream(GLB);
    Timer1.Enabled := True;
  finally
    GLB.Free;
  end;
  Invalidate;
end;

procedure TMain.GLPaint(Sender: TObject);
begin
  GLPanel.Project3D;

  glTranslatef(0, 0, tz - 100);


  if rx<>0 then glRotatef(rx,1,0,0);
  if ry<>0 then glRotatef(ry,0,1,0);
  if rz<>0 then glRotatef(rz,0,0,1);
  glMultMatrixf(@Matrix);

  // todo: auto position
  glRotatef( 20, 1, 0, 0);
  glRotatef(-45, 0, 1, 0);
  glTranslatef(0, -10, 0);

  glRotatef(Single(GetTickCount - Start)/50, 0, 1 ,0);
  glDisable(GL_LIGHTING);
  glBegin(GL_LINES);
    glColor3f(1, 0, 0); glVertex3f(0, 0, 0); glVertex3f(10, 0, 0);
    glColor3f(0, 1, 0); glVertex3f(0, 0, 0); glVertex3f(0, 10, 0);
    glColor3f(0, 0, 1); glVertex3f(0, 0, 0); glVertex3f(0, 0, 10);
  glEnd;

  glEnable(GL_LIGHTING);
  glEnable(GL_LIGHT0);
  glEnable(GL_COLOR_MATERIAL);
  glColor3f(1, 1, 1);
// todo: AutoScale
  glScalef(20, 20, 20);
  Model.Render;
end;

procedure TMain.GLPanelMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  Down := True;
  if Timer1.Enabled then
  begin
    Timer1.Tag := 1;
    Timer1.Enabled := False;
  end;
end;

procedure TMain.GLPanelMouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
begin
  if Down then
  begin
    if ssLeft in Shift then
    begin
      ry := ry + (x - Mouse.X);
      rx := rx + (y - Mouse.Y);
      GLPanel.Invalidate;
    end;

    if ssRight in Shift then
    begin
      rz := rz + (x - Mouse.X);
      tz := tz + (y - Mouse.Y);
      GLPanel.Invalidate;
    end;
  end;

  Mouse.X := X;
  Mouse.Y := Y;
end;

procedure TMain.GLPanelMouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  Down := False;
  Timer1.Enabled := Timer1.Tag = 1;
  glLoadIdentity();
  glRotatef(rx, 1, 0, 0);
  glRotatef(ry, 0, 1, 0);
  glRotatef(rz, 0, 0, 1);
  glMultMatrixf(@Matrix);
  glGetFloatV(GL_MODELVIEW_MATRIX, @Matrix);
  rx := 0;
  ry := 0;
  rz := 0;
  GLPanel.Invalidate;
end;

procedure TMain.Timer1Timer(Sender: TObject);
begin
  GLPanel.Invalidate;
end;

end.
