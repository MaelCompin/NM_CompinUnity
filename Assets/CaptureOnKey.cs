using UnityEngine;
#if ENABLE_INPUT_SYSTEM
using UnityEngine.InputSystem;
#endif

// Mettre ce script sur la Main Camera.
// En mode Play, appuie sur F9 : l'image est enregistree dans le dossier du projet
// (au meme niveau que le dossier Assets), avec le post-process.
public class CaptureOnKey : MonoBehaviour
{
    public string fileName = "capture_unity.png";
    [Range(1, 4)] public int superSize = 1;

    void Update()
    {
#if ENABLE_INPUT_SYSTEM
        if (Keyboard.current != null && Keyboard.current.f9Key.wasPressedThisFrame) Capture();
#else
        if (Input.GetKeyDown(KeyCode.F9)) Capture();
#endif
    }

    void Capture()
    {
        ScreenCapture.CaptureScreenshot(fileName, superSize);
        Debug.Log("Capture enregistree : " + System.IO.Path.GetFullPath(fileName));
    }
}
