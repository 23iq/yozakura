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
