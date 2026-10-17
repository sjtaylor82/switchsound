namespace SwitchSound;

public sealed record AudioDevice(string Id, string Name, bool IsDefault)
{
    public override string ToString() => Name;
}
