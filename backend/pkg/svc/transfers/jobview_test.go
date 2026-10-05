package transfers

import (
	"bufio"
	"context"
	"os"
	"os/exec"
	"strings"
	"testing"
	"time"

	"github.com/godbus/dbus/v5"
)

// privateBus starts a throwaway dbus-daemon; skips when unavailable.
func privateBus(t *testing.T) string {
	t.Helper()
	bin, err := exec.LookPath("dbus-daemon")
	if err != nil {
		t.Skip("dbus-daemon not installed")
	}
	dir := t.TempDir()
	conf := dir + "/bus.conf"
	must(t, os.WriteFile(conf, []byte(`<!DOCTYPE busconfig PUBLIC "-//freedesktop//DTD D-Bus Bus Configuration 1.0//EN" "http://www.freedesktop.org/standards/dbus/1.0/busconfig.dtd">
<busconfig><type>session</type><listen>unix:dir=`+dir+`</listen>
<policy context="default"><allow send_destination="*" eavesdrop="true"/><allow eavesdrop="true"/><allow own="*"/></policy></busconfig>`), 0o644))
	cmd := exec.Command(bin, "--config-file="+conf, "--print-address", "--nofork")
	out, err := cmd.StdoutPipe()
	must(t, err)
	must(t, cmd.Start())
	t.Cleanup(func() { cmd.Process.Kill(); cmd.Wait() })
	addr, err := bufio.NewReader(out).ReadString('\n')
	if err != nil {
		t.Fatalf("dbus-daemon address: %v", err)
	}
	return strings.TrimSpace(addr)
}

type jobViewHarness struct {
	t      *testing.T
	src    *jobViewSource
	client *dbus.Conn
	cancel context.CancelFunc
	done   chan struct{}
}

func startJobView(t *testing.T, addr string) *jobViewHarness {
	t.Helper()
	old := jobViewConnect
	jobViewConnect = func() (*dbus.Conn, error) { return dbus.Connect(addr) }
	t.Cleanup(func() { jobViewConnect = old })
	src := newJobViewSource()
	ctx, cancel := context.WithCancel(context.Background())
	h := &jobViewHarness{t: t, src: src, cancel: cancel, done: make(chan struct{})}
	go func() {
		src.Run(ctx, &Env{update: func([]Transfer) {}})
		close(h.done)
	}()
	client, err := dbus.Connect(addr)
	must(t, err)
	h.client = client
	t.Cleanup(func() {
		cancel()
		<-h.done
		client.Close()
	})
	return h
}

func (h *jobViewHarness) waitOwner() {
	h.t.Helper()
	deadline := time.Now().Add(3 * time.Second)
	for time.Now().Before(deadline) {
		var has bool
		if err := h.client.BusObject().Call("org.freedesktop.DBus.NameHasOwner", 0, jobViewServerName).Store(&has); err == nil && has {
			return
		}
		time.Sleep(20 * time.Millisecond)
	}
	h.t.Fatal("JobViewServer name never claimed")
}

func (h *jobViewHarness) item(key string) Transfer {
	h.t.Helper()
	for _, it := range h.src.items() {
		if it.Key == key {
			return it
		}
	}
	h.t.Fatalf("no item %q in %+v", key, h.src.items())
	return Transfer{}
}

func call(t *testing.T, obj dbus.BusObject, method string, args ...any) *dbus.Call {
	t.Helper()
	c := obj.Call(method, 0, args...)
	if c.Err != nil {
		t.Fatalf("%s: %v", method, c.Err)
	}
	return c
}

func TestJobViewV1CopyJobAndActions(t *testing.T) {
	h := startJobView(t, privateBus(t))
	h.waitOwner()
	server := h.client.Object(jobViewServerName, jobViewServerPath)
	var path dbus.ObjectPath
	must(t, call(t, server, "org.kde.JobViewServer.requestView", "Dolphin", "system-file-manager", int32(capKillable|capSuspendable)).Store(&path))
	view := h.client.Object(jobViewServerName, path)
	call(t, view, "org.kde.JobViewV2.setInfoMessage", "Copying")
	var ok bool
	must(t, call(t, view, "org.kde.JobViewV2.setDescriptionField", uint32(0), "Source", "file:///home/u/Videos/holiday.mkv").Store(&ok))
	call(t, view, "org.kde.JobViewV2.setDescriptionField", uint32(1), "Destination", "file:///mnt/usb/holiday.mkv")
	call(t, view, "org.kde.JobViewV2.setTotalAmount", uint64(100<<20), "bytes")
	call(t, view, "org.kde.JobViewV2.setTotalAmount", uint64(1), "files")
	call(t, view, "org.kde.JobViewV2.setProcessedAmount", uint64(25<<20), "bytes")
	call(t, view, "org.kde.JobViewV2.setSpeed", uint64(5<<20))
	call(t, view, "org.kde.JobViewV2.setDestUrl", dbus.MakeVariant("file:///mnt/usb/holiday.mkv"))

	it := h.item("job1")
	if !ok || it.App != "Dolphin" || it.Title != "holiday.mkv" || it.Path != "/mnt/usb/holiday.mkv" || it.Dir != "/mnt/usb" ||
		it.Processed != 25<<20 || it.Total != 100<<20 || it.Rate != float64(5<<20) || it.Kind != KindCopy || it.Detail != "Copying" {
		t.Fatalf("bad item %+v", it)
	}
	if len(it.Actions) != 2 || it.Actions[0] != ActionCancel || it.Actions[1] != ActionSuspend {
		t.Fatalf("actions %v", it.Actions)
	}

	// Actions become signals the job owner listens to
	must(t, h.client.AddMatchSignal(dbus.WithMatchInterface(ifaceViewV2)))
	sigs := make(chan *dbus.Signal, 4)
	h.client.Signal(sigs)
	must(t, h.src.Action("job1", ActionCancel))
	select {
	case sig := <-sigs:
		if sig.Name != ifaceViewV2+".cancelRequested" || sig.Path != path {
			t.Fatalf("signal %+v", sig)
		}
	case <-time.After(2 * time.Second):
		t.Fatal("cancelRequested not emitted")
	}

	call(t, view, "org.kde.JobViewV2.setSuspended", true)
	if it := h.item("job1"); it.State != StatePaused || it.Actions[1] != ActionResume {
		t.Fatalf("suspended %+v", it)
	}
	call(t, view, "org.kde.JobViewV2.terminate", "")
	if it := h.item("job1"); it.State != StateDone || it.Processed != it.Total || len(it.Actions) != 0 {
		t.Fatalf("terminated %+v", it)
	}
	// Removed (and unexported) after it was shown
	h.src.mu.Lock()
	h.src.now = func() time.Time { return time.Now().Add(jobDoneShown + time.Second) }
	h.src.mu.Unlock()
	if !h.src.prune() || len(h.src.items()) != 0 {
		t.Fatal("finished job not pruned")
	}
	if err := view.Call("org.kde.JobViewV2.setPercent", 0, uint32(5)).Err; err == nil {
		t.Fatal("view object should be gone")
	}
}

func TestJobViewV2UpdateAndFailure(t *testing.T) {
	old := desktopDataDirs
	desktopDataDirs = func() []string { return nil }
	defer func() { desktopDataDirs = old }()
	h := startJobView(t, privateBus(t))
	h.waitOwner()
	server := h.client.Object(jobViewServerName, jobViewServerPath)
	var path dbus.ObjectPath
	hints := map[string]dbus.Variant{"title": dbus.MakeVariant("Downloading")}
	must(t, call(t, server, "org.kde.JobViewServerV2.requestView", "org.kde.kget", int32(capKillable), hints).Store(&path))
	view := h.client.Object(jobViewServerName, path)
	call(t, view, "org.kde.JobViewV3.update", map[string]dbus.Variant{
		"descriptionLabel1": dbus.MakeVariant("Source"),
		"descriptionValue1": dbus.MakeVariant("https://mirror.example/arch.iso"),
		"descriptionLabel2": dbus.MakeVariant("Destination"),
		"descriptionValue2": dbus.MakeVariant("file:///home/u/Downloads/arch.iso"),
		"totalBytes":        dbus.MakeVariant(uint64(800 << 20)),
		"processedBytes":    dbus.MakeVariant(uint64(200 << 20)),
		"speed":             dbus.MakeVariant(uint64(10 << 20)),
		"percent":           dbus.MakeVariant(uint32(25)),
	})
	it := h.item("job1")
	if it.App != "Kget" || it.AppIcon != "org.kde.kget" || it.Title != "arch.iso" || it.Path != "/home/u/Downloads/arch.iso" ||
		it.Processed != 200<<20 || it.Total != 800<<20 || it.Kind != KindDownload || it.Detail != "Downloading" {
		t.Fatalf("bad item %+v", it)
	}
	if len(it.Actions) != 1 || it.Actions[0] != ActionCancel {
		t.Fatalf("actions %v", it.Actions)
	}
	call(t, view, "org.kde.JobViewV3.terminate", uint32(1), "Disk full", map[string]dbus.Variant{})
	if it := h.item("job1"); it.State != StateFailed || it.Detail != "Disk full" {
		t.Fatalf("failure %+v", it)
	}
}

func TestJobViewStaysIdleWhenNameIsTaken(t *testing.T) {
	addr := privateBus(t)
	owner, err := dbus.Connect(addr)
	must(t, err)
	defer owner.Close()
	if r, err := owner.RequestName(jobViewServerName, dbus.NameFlagDoNotQueue); err != nil || r != dbus.RequestNameReplyPrimaryOwner {
		t.Fatalf("could not take the name: %v %v", r, err)
	}
	old := jobViewConnect
	jobViewConnect = func() (*dbus.Conn, error) { return dbus.Connect(addr) }
	defer func() { jobViewConnect = old }()
	done := make(chan struct{})
	go func() {
		newJobViewSource().Run(context.Background(), &Env{update: func([]Transfer) {}})
		close(done)
	}()
	select {
	case <-done:
	case <-time.After(3 * time.Second):
		t.Fatal("Run should return when Plasma owns the name")
	}
}

func TestDesktopEntryInfo(t *testing.T) {
	dir := t.TempDir()
	must(t, os.MkdirAll(dir+"/applications", 0o755))
	must(t, os.WriteFile(dir+"/applications/org.kde.dolphin.desktop", []byte("[Desktop Entry]\nName=Dolphin\nIcon=system-file-manager\n[Desktop Action x]\nName=Other\n"), 0o644))
	old := desktopDataDirs
	desktopDataDirs = func() []string { return []string{dir + "/applications"} }
	defer func() { desktopDataDirs = old }()
	if n, i := desktopEntryInfo("org.kde.dolphin"); n != "Dolphin" || i != "system-file-manager" {
		t.Fatalf("got %q %q", n, i)
	}
	if n, i := desktopEntryInfo("org.example.missing"); n != "Missing" || i != "org.example.missing" {
		t.Fatalf("fallback %q %q", n, i)
	}
}

// The production connector must authenticate and say Hello, or RequestName
// fails and the JobView server silently never starts.
func TestJobViewConnectIsUsable(t *testing.T) {
	addr := privateBus(t)
	t.Setenv("DBUS_SESSION_BUS_ADDRESS", addr)
	type result struct {
		r   dbus.RequestNameReply
		err error
	}
	got := make(chan result, 1)
	go func() {
		conn, err := jobViewConnect()
		if err != nil {
			got <- result{err: err}
			return
		}
		defer conn.Close()
		r, err := conn.RequestName(jobViewServerName, dbus.NameFlagDoNotQueue)
		got <- result{r, err}
	}()
	select {
	case res := <-got:
		if res.err != nil || res.r != dbus.RequestNameReplyPrimaryOwner {
			t.Fatalf("RequestName on the default connection: %v %v", res.r, res.err)
		}
	case <-time.After(5 * time.Second):
		t.Fatal("RequestName hung: connection not authenticated (no Auth/Hello)")
	}
}
