using UnityEditor;
using UnityEngine;

// À placer dans un dossier "Editor" (Assets/Editor/MesurerTailles.cs).
// Sélectionne des objets dans la Hierarchy, puis menu Outils > Mesurer la taille (cm).
// Le résultat s'affiche dans la Console : largeur (X), hauteur (Y), profondeur (Z) en cm.
public static class MesurerTailles
{
    [MenuItem("Outils/Mesurer la taille (cm)")]
    static void Mesurer()
    {
        foreach (var go in Selection.gameObjects)
        {
            var renderers = go.GetComponentsInChildren<Renderer>();
            if (renderers.Length == 0) continue;

            Bounds b = renderers[0].bounds;
            foreach (var r in renderers) b.Encapsulate(r.bounds);

            Vector3 cm = b.size * 100f;
            Debug.Log($"{go.name} : X {cm.x:F1} / Y (hauteur) {cm.y:F1} / Z {cm.z:F1} cm");
        }
    }
}
