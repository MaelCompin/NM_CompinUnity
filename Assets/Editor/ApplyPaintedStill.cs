#if UNITY_EDITOR
using System.Collections.Generic;
using UnityEditor;
using UnityEngine;

// A placer dans un dossier "Editor" (ex : Assets/Editor/ApplyPaintedStill.cs).
// Utilisation : selectionne les objets parents dans la Hierarchy,
// puis menu Tools > Appliquer PaintedStill a la selection.
public static class ApplyPaintedStill
{
    const string ShaderName = "Custom/PaintedStill";
    const string OutputFolder = "Assets/Materials_Painted";

    [MenuItem("Tools/Appliquer PaintedStill a la selection")]
    static void Apply()
    {
        Shader shader = Shader.Find(ShaderName);
        if (shader == null)
        {
            Debug.LogError("Shader introuvable : " + ShaderName);
            return;
        }

        if (Selection.gameObjects.Length == 0)
        {
            Debug.LogWarning("Selectionne d'abord un ou plusieurs objets dans la Hierarchy.");
            return;
        }

        if (!AssetDatabase.IsValidFolder(OutputFolder))
            AssetDatabase.CreateFolder("Assets", "Materials_Painted");

        // un seul nouveau materiau par ancien materiau (evite les doublons)
        var cache = new Dictionary<Material, Material>();
        int rendererCount = 0;
        int skippedTransparent = 0;

        foreach (GameObject root in Selection.gameObjects)
        {
            foreach (Renderer r in root.GetComponentsInChildren<Renderer>(true))
            {
                Material[] mats = r.sharedMaterials;
                bool changed = false;

                // si l'objet vient d'un prefab/modele importe, on peut retrouver
                // ses materiaux d'origine meme s'ils ont deja ete remplaces
                Material[] sourceMats = null;
                Renderer sourceRenderer = PrefabUtility.GetCorrespondingObjectFromSource(r);
                if (sourceRenderer != null && sourceRenderer.sharedMaterials.Length == mats.Length)
                    sourceMats = sourceRenderer.sharedMaterials;

                for (int i = 0; i < mats.Length; i++)
                {
                    Material src = mats[i];
                    if (src != null && src.shader == shader && sourceMats != null && sourceMats[i] != null)
                        src = sourceMats[i];

                    if (src == null || src.shader == shader) continue;

                    // on garde les materiaux transparents (verre) tels quels
                    if (src.renderQueue >= 3000)
                    {
                        if (mats[i] != src)
                        {
                            mats[i] = src;
                            changed = true;
                        }
                        skippedTransparent++;
                        continue;
                    }

                    if (!cache.TryGetValue(src, out Material dst))
                    {
                        dst = new Material(shader);

                        // texture
                        if (src.HasProperty("_BaseMap"))
                            dst.SetTexture("_BaseMap", src.GetTexture("_BaseMap"));
                        else if (src.HasProperty("_MainTex"))
                            dst.SetTexture("_BaseMap", src.GetTexture("_MainTex"));

                        // couleur
                        if (src.HasProperty("_BaseColor"))
                            dst.SetColor("_BaseColor", src.GetColor("_BaseColor"));
                        else if (src.HasProperty("_Color"))
                            dst.SetColor("_BaseColor", src.GetColor("_Color"));

                        // feuillage decoupe (masked)
                        if (src.IsKeywordEnabled("_ALPHATEST_ON") && src.HasProperty("_Cutoff"))
                            dst.SetFloat("_Cutoff", Mathf.Max(0.01f, src.GetFloat("_Cutoff")));

                        string path = AssetDatabase.GenerateUniqueAssetPath(
                            OutputFolder + "/" + src.name + "_Painted.mat");
                        AssetDatabase.CreateAsset(dst, path);
                        cache[src] = dst;
                    }

                    mats[i] = dst;
                    changed = true;
                }

                if (changed)
                {
                    Undo.RecordObject(r, "Appliquer PaintedStill");
                    r.sharedMaterials = mats;
                    EditorUtility.SetDirty(r);
                    rendererCount++;
                }
            }
        }

        AssetDatabase.SaveAssets();
        Debug.Log("PaintedStill applique sur " + rendererCount + " renderers, "
                  + cache.Count + " materiaux crees dans " + OutputFolder
                  + ", " + skippedTransparent + " emplacements transparents ignores.");
    }
}
#endif
