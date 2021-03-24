unit Execute.GLB.FMX;

interface

uses
  Execute.GLB,
  System.Types,
  System.Classes,
  System.Math,
  System.Math.Vectors,
  FMX.Types,
  FMX.Controls3D,
  FMX.MaterialSources,
  FMX.Objects3D;

type
  TGLBModelReader = class(TGLBModel)
  private
    LRoot: TFmxObject;
    LMaterials: TArray<TLightMaterialSource>;
    procedure CreateNodes(AParent: TFmxObject; ANodes: TArray<Cardinal>);
    procedure CreateNode(AParent: TFmxObject; ANode: Cardinal);
    procedure CreateMesh(AParent: TFmxObject; AMesh: Cardinal);
    procedure CreatePrimitives(AParent: TFmxObject; const APrimitives: TArray<TPrimitive>);
    function CreateMaterial(AMaterial: Cardinal): TLightMaterialSource;
  end;

  TGLBFMXModel = class(TDummy)
  public
    procedure LoadFromStream(AStream: TStream);
  end;

implementation

{ TGLBFMXModel }

procedure TGLBFMXModel.LoadFromStream(AStream: TStream);
var
  GLB: TGLBModelReader;
begin
  DeleteChildren;
  Self.HitTest := False;
  Self.Scale.X := +2;
  Self.Scale.Y := -2;
  Self.Scale.Z := -2;
  GLB := TGLBModelReader.Create;
  try
    GLB.LoadFromStream(AStream);
    GLB.LRoot := Self;
    SetLength(GLB.LMaterials, Length(GLB.FMaterials));
    GLB.CreateNodes(Self, GLB.FScene);
  finally
    GLB.Free;
  end;
end;

{ TGLBModelReader }

procedure TGLBModelReader.CreateNodes(AParent: TFmxObject;
  ANodes: TArray<Cardinal>);
var
  Index: Integer;
begin
  for Index := 0 to Length(ANodes) - 1 do
  begin
    CreateNode(AParent, ANodes[Index]);
  end;
end;

type
  TControl3DHelper = class helper for TControl3D
    procedure SetMatrix(const M: TMatrix3D);
  end;

procedure TControl3DHelper.SetMatrix(const M: TMatrix3D);
begin
  FLocalMatrix := M;
  RecalcAbsolute;
//  RebuildRenderingList;
//  Repaint;
end;

function Quaternion(x, y, z, w: Single): TMatrix3D;
// https://www.euclideanspace.com/maths/geometry/rotations/conversions/quaternionToMatrix/index.htm
var
  M: TMatrix3D;
begin
  with Result do
  begin
    m11 :=  w; m12 :=  z; m13 := -y; m14 :=  x;
    m21 := -z; m22 :=  w; m23 :=  x; m24 :=  y;
    m31 :=  y; m32 := -x; m33 :=  w; m34 :=  z;
    m41 := -x; m42 := -y; m43 := -z; m44 :=  w;
  end;
  with M do
  begin
    m11 :=  w; m12 :=  z; m13 := -y; m14 := -x;
    m21 := -z; m22 :=  w; m23 :=  x; m24 := -y;
    m31 :=  y; m32 := -x; m33 :=  w; m34 := -z;
    m41 :=  x; m42 :=  y; m43 :=  z; m44 :=  w;
  end;
  Result := Result * M;
end;

procedure TGLBModelReader.CreateNode(AParent: TFmxObject; ANode: Cardinal);
var
  LNode: TDummy;
  LMatrix: TMatrix3D;
begin
  LNode := TDummy.Create(LRoot);
  LNode.Parent := AParent;
  with FNodes[ANode] do
  begin
    LMatrix := TMatrix3D.Identity;
    if Length(scale) = 3 then
    begin
//      LNode.Scale.X := scale[0];
//      LNode.Scale.Y := scale[1];
//      LNode.Scale.Z := scale[2];
      LMatrix := LMatrix * TMatrix3D.CreateScaling(TPoint3D.Create(scale[0], scale[1], scale[2]));
    end;
    if Length(rotation) = 4 then
    begin
//      LMatrix := LMatrix * TQuaternion3D.Create(TPoint3D.Create(rotation[0], rotation[1], rotation[2]), rotation[3]);
      LMatrix := LMatrix * Quaternion(rotation[0], rotation[1], rotation[2], rotation[3]);
    end;
    if Length(translation) = 3 then
    begin
//      LNode.Position.X := translation[0];
//      LNode.Position.Y := translation[1];
//      LNode.Position.Z := translation[2];
      LMatrix := LMatrix * TMatrix3D.CreateTranslation(TPoint3D.Create(translation[0], translation[1], translation[2]));
    end;
    LNode.SetMatrix(LMatrix);
    CreateMesh(LNode, mesh);
    CreateNodes(LNode, children);
  end;
end;

procedure TGLBModelReader.CreateMesh(AParent: TFmxObject; AMesh: Cardinal);
begin
  if AMesh = NULL_OFFSET then
    Exit;
  CreatePrimitives(AParent, FMeshes[AMesh].primitives);
end;

procedure TGLBModelReader.CreatePrimitives(AParent: TFmxObject; const APrimitives: TArray<TPrimitive>);
var
  Index: Integer;
  LMesh: TMesh;
  Iter: Integer;
  p1: ^TPoint3D;
  p2: ^TPoint3D;
  p3: ^TPointF;
  p4: ^Word;
begin
  for Index := 0 to Length(APrimitives) - 1 do
  begin
    with APrimitives[Index] do
    begin
      LMesh := TMesh.Create(LRoot);
      LMesh.WrapMode := TMeshWrapMode.Original;
      LMesh.Parent := AParent;
      LMesh.HitTest := False;
      LMesh.TwoSide := True;
      LMesh.Data.VertexBuffer.Length := vertexCount;
      p1 := @FBuffer[position];
      p2 := @FBuffer[normal];
      p3 := @FBuffer[texcoord];
      for Iter := 0 to vertexCount - 1 do
      begin
        LMesh.Data.VertexBuffer.Vertices[Iter] := p1^;
        Inc(p1);
        LMesh.Data.VertexBuffer.Normals[Iter] := p2^;
        Inc(p2);
        if texcoord <> NULL_OFFSET then
        begin
          LMesh.Data.VertexBuffer.TexCoord0[Iter] := p3^;
          Inc(p3);
        end;
      end;
      p4 := @FBuffer[indices];
      LMesh.Data.IndexBuffer.Length := indiceCount;
      for Iter := 0 to indiceCount - 1 do
      begin
        LMesh.Data.IndexBuffer[Iter] := p4^;
        Inc(p4);
      end;
      LMesh.MaterialSource := CreateMaterial(Material);
    end;
  end;
end;

function TGLBModelReader.CreateMaterial(AMaterial: Cardinal): TLightMaterialSource;
var
  Stream: TBytesStream;
begin
  Result := LMaterials[AMaterial];
  if Result = nil then
  begin
    Result := TLightMaterialSource.Create(LRoot);
    if FMaterials[AMaterial].Image = NULL_OFFSET then
    begin
      if Length(FMaterials[AMaterial].BaseColorFactor) = 4 then
      begin
        Result.Diffuse := FMaterials[AMaterial].GetColor;
      end;
    end else begin
      Stream := TBytesStream.Create(FBuffer);
      try
        Stream.Position := FImages[FMaterials[AMaterial].Image].Offset;
        Result.Texture.LoadFromStream(Stream);
      finally
        Stream.Free;
      end;
    end;
    LMaterials[AMaterial] := Result;
  end;
end;

end.
