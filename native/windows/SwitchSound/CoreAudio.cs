using System.Runtime.InteropServices;
using NAudio.CoreAudioApi;

namespace SwitchSound;

internal static class CoreAudio
{
    public static IReadOnlyList<AudioDevice> ListOutputs()
    {
        using var enumerator = new MMDeviceEnumerator();
        using var defaultDevice = enumerator.GetDefaultAudioEndpoint(DataFlow.Render, Role.Multimedia);
        var devices = enumerator.EnumerateAudioEndPoints(DataFlow.Render, DeviceState.Active);
        var result = new List<AudioDevice>(devices.Count);
        foreach (var device in devices)
        {
            result.Add(new AudioDevice(device.ID, device.FriendlyName, device.ID == defaultDevice.ID));
            device.Dispose();
        }
        return result;
    }

    public static void SetDefault(string deviceId)
    {
        var classId = new Guid("870AF99C-171D-4F9E-AF0D-E63DF40C2BC9");
        var interfaceId = new Guid("F8679F50-850A-41CF-9C72-430F290290C8");
        Marshal.ThrowExceptionForHR(CoCreateInstance(ref classId, IntPtr.Zero, 23, ref interfaceId, out var policy));
        try
        {
            var vtable = Marshal.ReadIntPtr(policy);
            var methodPointer = Marshal.ReadIntPtr(vtable, 13 * IntPtr.Size);
            var setDefaultEndpoint = Marshal.GetDelegateForFunctionPointer<SetDefaultEndpoint>(methodPointer);
            foreach (var role in new[] { 0, 1, 2 })
                Marshal.ThrowExceptionForHR(setDefaultEndpoint(policy, deviceId, role));
        }
        finally
        {
            Marshal.Release(policy);
        }
    }

    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    private delegate int SetDefaultEndpoint(
        IntPtr self,
        [MarshalAs(UnmanagedType.LPWStr)] string deviceId,
        int role);

    [DllImport("ole32.dll")]
    private static extern int CoCreateInstance(
        ref Guid classId,
        IntPtr outer,
        uint context,
        ref Guid interfaceId,
        out IntPtr instance);
}
