using System.IO;

namespace SwitchSound;

internal static class SettingsStore
{
    private static readonly string PathName = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
        "SwitchSound", "selected-device.txt");

    public static string Load()
    {
        try { return File.ReadAllText(PathName).Trim(); }
        catch (IOException) { return ""; }
        catch (UnauthorizedAccessException) { return ""; }
    }

    public static void Save(string deviceId)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(PathName)!);
        File.WriteAllText(PathName, deviceId);
    }
}
