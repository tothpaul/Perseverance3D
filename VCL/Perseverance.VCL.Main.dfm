object Main: TMain
  Left = 0
  Top = 0
  Caption = 'Mars Perseverance Rover, 3D Model'
  ClientHeight = 454
  ClientWidth = 921
  Color = clBtnFace
  CustomTitleBar.CaptionAlignment = taCenter
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  PixelsPerInch = 96
  TextHeight = 13
  object Panel1: TPanel
    Left = 0
    Top = 0
    Width = 921
    Height = 41
    Align = alTop
    Caption = 'Panel1'
    ParentBackground = False
    ParentColor = True
    ShowCaption = False
    TabOrder = 0
    object Label1: TLabel
      AlignWithMargins = True
      Left = 4
      Top = 4
      Width = 19
      Height = 33
      Align = alLeft
      Caption = 'URL'
      Layout = tlCenter
      ExplicitHeight = 13
    end
    object edURL: TEdit
      AlignWithMargins = True
      Left = 33
      Top = 8
      Width = 798
      Height = 25
      Margins.Left = 7
      Margins.Top = 7
      Margins.Right = 7
      Margins.Bottom = 7
      Align = alClient
      TabOrder = 0
      Text = 
        'https://mars.nasa.gov/system/resources/gltf_files/25042_Persever' +
        'ance.glb'
      ExplicitHeight = 21
    end
    object btGo: TButton
      AlignWithMargins = True
      Left = 838
      Top = 8
      Width = 75
      Height = 25
      Margins.Left = 0
      Margins.Top = 7
      Margins.Right = 7
      Margins.Bottom = 7
      Align = alRight
      Caption = 'GO!'
      TabOrder = 1
      OnClick = btGoClick
    end
  end
  inline GLPanel: TGLPanel
    Left = 0
    Top = 41
    Width = 921
    Height = 413
    Align = alClient
    TabOrder = 1
    OnMouseDown = GLPanelMouseDown
    OnMouseMove = GLPanelMouseMove
    OnMouseUp = GLPanelMouseUp
    ExplicitTop = 41
    ExplicitWidth = 921
    ExplicitHeight = 413
  end
  object NetHTTPClient: TNetHTTPClient
    UserAgent = 'Embarcadero URI Client/1.0'
    Left = 112
    Top = 80
  end
  object Timer1: TTimer
    Enabled = False
    Interval = 40
    OnTimer = Timer1Timer
    Left = 216
    Top = 80
  end
end
