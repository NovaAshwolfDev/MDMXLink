using System.Collections.Generic;
using System;
using UnityEngine;
using UnityEditor;
using UnityEditor.AnimatedValues;

public class MDMXLinkGUI : ShaderGUI
{
    private GUIStyle label;
    private GUIStyle verLabel;
    private GUIStyle header;
    private string curVersion;
    private static GUIStyle customBoxStyle;
    private MaterialEditor materialEditorInstance;
    GUIStyle foldoutHeaderStyle;
    Color foldoutBgColor = new Color(0.2f, 0.2f, 0.2f, 1f);
    Dictionary<string, AnimBool> animatedStates = new();

    string getVersion()
    {
        curVersion = "1.0.0";
        return curVersion;
    }
  
    void InitStyles()
    {
        if (foldoutHeaderStyle == null)
        {
            foldoutHeaderStyle = new GUIStyle(EditorStyles.label)
            {
                fontStyle = FontStyle.Bold,
                normal = { textColor = Color.white },
                padding = { bottom = 3 }
            };
        }
        if (label == null)
        {
            label = new GUIStyle(EditorStyles.miniBoldLabel)
            {
                alignment = TextAnchor.MiddleCenter,
                fontSize = 25,
                clipping = TextClipping.Overflow
            };
        }
        if (verLabel == null)
        {
            verLabel = new GUIStyle(EditorStyles.miniLabel)
            {
                alignment = TextAnchor.MiddleCenter,
                fontSize = 14,
                clipping = TextClipping.Overflow
            };
        }
        if (header == null)
        {
            header = new GUIStyle(EditorStyles.boldLabel)
            {
                wordWrap = true,
                fontSize = 15
            };
        }
    }
    
    void DrawTriangle(Rect rect, float angleDeg, Color color)
    {
        Vector2 center = rect.center;
        float size = 4f;
        Vector2[] triangle = new Vector2[]
        {
            new Vector2(-size, -size),
            new Vector2(size, 0),
            new Vector2(-size, size)
        };

        Matrix4x4 m = Matrix4x4.TRS(center, Quaternion.Euler(0, 0, angleDeg), Vector3.one);
        for (int i = 0; i < triangle.Length; i++)
            triangle[i] = m.MultiplyPoint(triangle[i]);

        Vector3[] triangle3D = Array.ConvertAll(triangle, v => new Vector3(v.x, v.y, 0));

        Handles.color = color;
        Handles.DrawAAConvexPolygon(triangle3D);
    }

    bool Foldout(string propName, string label, bool defaultState = false, Action contentDrawer = null)
    {
        if (!animatedStates.ContainsKey(propName))
        {
            var animBool = new AnimBool(defaultState);
            animBool.valueChanged.AddListener(() => materialEditorInstance.Repaint());
            animatedStates[propName] = animBool;
        }

        var anim = animatedStates[propName];
        float cornerRadius = 8f;

        Rect rect = GUILayoutUtility.GetRect(16, 22, GUILayout.ExpandWidth(true));
        Handles.BeginGUI();
        DrawRoundedRect(rect, new Color(0.18f, 0.18f, 0.18f, 1f), new Color(0.3f, 0.3f, 0.3f, 1f), cornerRadius);
        Handles.EndGUI();

        Rect arrowRect = new Rect(rect.x + 10, rect.y + 3, 16, 16);
        Rect labelRect = new Rect(arrowRect.xMax + 8, rect.y + 3, rect.width - 40, 16);

        DrawTriangle(arrowRect, anim.target ? 90 : 0, Color.white);
        EditorGUI.LabelField(labelRect, label, foldoutHeaderStyle);

        if (Event.current.type == EventType.MouseDown && rect.Contains(Event.current.mousePosition))
        {
            anim.target = !anim.target;
            GUI.changed = true;
            Event.current.Use();
        }

        bool wasShown = EditorGUILayout.BeginFadeGroup(anim.faded);
        if (wasShown)
        {
            EditorGUILayout.BeginVertical(EditorStyles.helpBox);
            contentDrawer?.Invoke();
            EditorGUILayout.EndVertical();
        }
        EditorGUILayout.EndFadeGroup();

        return anim.target;
    }


    void DrawRoundedRect(Rect rect, Color fillColor, Color borderColor, float radius)
    {
        Vector3[] points = GetRoundedRectPath(rect, radius, 8);

        Handles.color = fillColor;
        Handles.DrawAAConvexPolygon(points);

        Handles.color = borderColor;
        Vector3[] closedPoints = new Vector3[points.Length + 1];
        points.CopyTo(closedPoints, 0);
        closedPoints[points.Length] = points[0];
        Handles.DrawAAPolyLine(2f, closedPoints);
    }

    Vector3[] GetRoundedRectPath(Rect r, float radius, int cornerSegments)
    {
        List<Vector3> points = new List<Vector3>();
        float x = r.x;
        float y = r.y;
        float w = r.width;
        float h = r.height;

        radius = Mathf.Min(radius, Mathf.Min(w, h) / 2f);

        Vector2 topLeft = new Vector2(x + radius, y + radius);
        Vector2 topRight = new Vector2(x + w - radius, y + radius);
        Vector2 bottomRight = new Vector2(x + w - radius, y + h - radius);
        Vector2 bottomLeft = new Vector2(x + radius, y + h - radius);

        void AddCornerArc(Vector2 center, float startAngle, float endAngle)
        {
            float step = (endAngle - startAngle) / cornerSegments;
            for (int i = 0; i <= cornerSegments; i++)
            {
                float angle = startAngle + step * i;
                float rad = Mathf.Deg2Rad * angle;
                points.Add(new Vector3(center.x + Mathf.Cos(rad) * radius, center.y + Mathf.Sin(rad) * radius, 0));
            }
        }

        AddCornerArc(topLeft, 180f, 270f);
        AddCornerArc(topRight, 270f, 360f);
        AddCornerArc(bottomRight, 0f, 90f);
        AddCornerArc(bottomLeft, 90f, 180f);

        return points.ToArray();
    }

    public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] properties)
    {
        materialEditorInstance = materialEditor;
        InitStyles();

        EditorGUILayout.Space(5);
        EditorGUILayout.LabelField("MDMX Link", label);
        EditorGUILayout.Space(5);
        EditorGUILayout.LabelField("By Milo", verLabel);
        EditorGUILayout.LabelField("Version: " + getVersion(), verLabel);
        EditorGUILayout.Space(20);

        if (Foldout("MDMXLinkSettings", "MDMX Link Settings", false, () =>
        {
            MaterialProperty fixtureTypeProp = FindProperty("_FixtureType", properties);
            MaterialProperty channelProp     = FindProperty("_Channel", properties);
            MaterialProperty countProp       = FindProperty("_FixtureCount", properties);

            MaterialProperty albedoProp      = FindProperty("_Albedo", properties);
            MaterialProperty normalProp      = FindProperty("_Normal", properties);
            MaterialProperty maskProp        = FindProperty("_MaskMap", properties);
            MaterialProperty metallicProp    = FindProperty("_Metallic", properties);
            MaterialProperty smoothProp      = FindProperty("_Smoothness", properties);

            EditorGUI.BeginChangeCheck();
            MDMXFixtureType fixtureEnum =
                (MDMXFixtureType)(int)fixtureTypeProp.floatValue;

            fixtureEnum = (MDMXFixtureType)EditorGUILayout.EnumPopup(
                "Fixture Type", fixtureEnum
            );

            if (EditorGUI.EndChangeCheck())
            {
                fixtureTypeProp.floatValue = (float)(int)fixtureEnum;
            }

            materialEditorInstance.ShaderProperty(channelProp, channelProp.displayName);
            materialEditorInstance.ShaderProperty(countProp, countProp.displayName);

            EditorGUILayout.Space(10);

            materialEditorInstance.ShaderProperty(albedoProp, albedoProp.displayName);
            materialEditorInstance.ShaderProperty(normalProp, normalProp.displayName);
            materialEditorInstance.ShaderProperty(maskProp, maskProp.displayName);

            EditorGUILayout.Space(10);

            materialEditorInstance.ShaderProperty(metallicProp, metallicProp.displayName);
            materialEditorInstance.ShaderProperty(smoothProp, smoothProp.displayName);

        })) { }

    }

}



public enum MDMXFixtureType
{
    TiltBar = 0,
    Spotlight = 1,
    Laser = 2
}
