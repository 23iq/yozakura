package extras

import "testing"

func TestValidateGPUVariantsPerMethod(t *testing.T) {
	c := base()
	c.Entries[0].Install.Arch = &Method{Pkgs: []string{"x"}, GPU: GPUVariants{"voodoo": {"x"}}}
	if c.Validate() == nil {
		t.Error("unknown gpu key accepted")
	}
	c.Entries[0].Install.Arch = &Method{Pkgs: []string{"x"}, GPU: GPUVariants{"nvidia": {"X;rm"}}}
	if c.Validate() == nil {
		t.Error("bad gpu package accepted")
	}
	c.Entries[0].Install.Fedora = nil
	c.Entries[0].Install.Arch = &Method{Pkgs: []string{"x"}, GPU: GPUVariants{"nvidia": {"x-cuda"}}}
	if err := c.Validate(); err != nil {
		t.Error(err)
	}
}

func TestRealOllamaGPUOnlyOnArch(t *testing.T) {
	e, _ := loadReal(t).Get("ollama")
	if e.Install.Arch == nil || e.Install.Arch.GPU["nvidia"][0] != "ollama-cuda" {
		t.Fatalf("arch gpu = %+v", e.Install.Arch)
	}
	if e.Install.Fedora == nil || len(e.Install.Fedora.GPU) != 0 {
		t.Fatalf("fedora gpu = %+v", e.Install.Fedora)
	}
}

// Steam needs the 32-bit Vulkan/GL driver of the GPU or games do not start.
func TestRealSteamGPUVariants(t *testing.T) {
	e, _ := loadReal(t).Get("steam")
	want := map[string]string{"amd": "lib32-vulkan-radeon", "intel": "lib32-vulkan-intel", "nvidia": "lib32-nvidia-utils"}
	for gpu, pkg := range want {
		got := e.Install.Arch.GPU[gpu]
		if len(got) == 0 || got[0] != "steam" || !contains(got, pkg) {
			t.Errorf("steam %s = %v, want steam + %s", gpu, got, pkg)
		}
	}
}
