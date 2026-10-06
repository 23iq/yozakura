package extras

// ShellArgs maps a known repo shell script to its arguments for the host.
// voice_setup.sh: nvidia passes nothing (the script auto-detects nvcc and
// falls back to CPU), amd/intel build the Vulkan backend, no GPU builds CPU.
func ShellArgs(script string, p Platform) []string {
	if script != "voice_setup.sh" {
		return nil
	}
	switch p.GPU {
	case "amd", "intel":
		return []string{"--vulkan"}
	case "none":
		return []string{"--cpu"}
	}
	return nil
}
