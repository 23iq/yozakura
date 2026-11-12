package convert

// The conversion table: which targets each source format offers, which
// engines convert it (in order of preference), which targets are popular
// (shown first, as big chips) and the smart default. Everything the
// converter proposes comes from these four tables.

// route: a target and the engines that can produce it, best first.
type route struct {
	to  string
	via []Engine
}

// family: the routes shared by a group of source formats. A source may be
// in several families (gif: an image and a short video); the first route
// for a target wins.
type family struct {
	sources []string
	routes  []route
}

var (
	img     = []Engine{EngineMagick, EngineNative, EngineFFmpeg}
	imgOnly = []Engine{EngineMagick, EngineFFmpeg}
	ff      = []Engine{EngineFFmpeg}
	office  = []Engine{EngineSoffice}
	pan     = []Engine{EnginePandoc}
	native  = []Engine{EngineNative}
)

func routes(via []Engine, to ...string) []route {
	out := make([]route, len(to))
	for i, t := range to {
		out[i] = route{to: t, via: via}
	}
	return out
}

func join(parts ...[]route) []route {
	var out []route
	for _, p := range parts {
		out = append(out, p...)
	}
	return out
}

var families = []family{
	// raster images
	{sources: []string{"png", "jpg", "webp", "avif", "heic", "jxl", "gif", "bmp", "tiff", "ico", "tga", "psd"},
		routes: join(
			routes(img, "png", "jpg"),
			routes(imgOnly, "webp", "avif"),
			routes(img, "gif", "bmp", "tiff"),
			routes([]Engine{EngineMagick}, "ico", "jxl"),
			routes(imgOnly, "tga"),
			routes([]Engine{EngineMagick}, "pdf"),
		)},
	// vector images
	{sources: []string{"svg"},
		routes: join(
			routes([]Engine{EngineRsvg, EngineMagick}, "png", "pdf"),
			routes([]Engine{EngineMagick}, "jpg", "webp", "avif", "tiff", "ico"),
		)},
	// an animated gif is also a short video
	{sources: []string{"gif"}, routes: routes(ff, "mp4", "webm")},
	// audio
	{sources: []string{"mp3", "wav", "flac", "ogg", "opus", "m4a", "aac", "aiff", "wma"},
		routes: routes(ff, "mp3", "wav", "flac", "ogg", "opus", "m4a", "aac", "aiff")},
	// video, and its audio track
	{sources: []string{"mp4", "mkv", "webm", "mov", "avi", "wmv", "flv", "mpeg", "3gp"},
		routes: join(
			routes(ff, "mp4", "webm", "mkv", "mov", "avi", "gif"),
			routes(ff, "mp3", "wav", "flac", "ogg", "opus", "m4a", "aac"),
		)},
	// word processing
	{sources: []string{"docx", "odt"},
		routes: join(
			routes(office, "pdf", "docx", "odt", "rtf", "doc"),
			routes([]Engine{EngineSoffice, EnginePandoc}, "txt"),
			routes([]Engine{EnginePandoc, EngineSoffice}, "html"),
			routes(pan, "md", "epub", "rst"),
		)},
	{sources: []string{"doc", "rtf"}, routes: routes(office, "pdf", "docx", "odt", "rtf", "doc", "txt", "html")},
	{sources: []string{"txt"},
		routes: join(
			routes(office, "pdf"),
			routes([]Engine{EngineSoffice, EnginePandoc}, "docx", "odt"),
			routes(office, "rtf"),
			routes(pan, "html", "epub"),
		)},
	// spreadsheets and slides
	{sources: []string{"xlsx", "xls", "ods"}, routes: routes(office, "pdf", "xlsx", "ods", "csv", "html")},
	{sources: []string{"pptx", "ppt", "odp"}, routes: routes(office, "pdf", "pptx", "odp")},
	// pdf
	{sources: []string{"pdf"},
		routes: join(
			routes(office, "docx", "odt"),
			routes([]Engine{EnginePdftoppm, EngineMagick}, "png", "jpg"),
			routes([]Engine{EnginePdftotext}, "txt"),
		)},
	// markup and ebooks (html prints to pdf directly in LibreOffice)
	{sources: []string{"html"}, routes: routes(office, "pdf")},
	{sources: []string{"md", "html", "rst", "org", "tex", "epub"},
		routes: join(
			routes([]Engine{EngineDocPDF}, "pdf"),
			routes(pan, "docx", "odt", "html", "md", "epub", "txt", "rst", "org", "tex"),
		)},
	// data (native Go)
	{sources: []string{"json"}, routes: routes(native, "yaml", "toml", "csv")},
	{sources: []string{"yaml"}, routes: routes(native, "json", "toml", "csv")},
	{sources: []string{"toml"}, routes: routes(native, "json", "yaml")},
	{sources: []string{"csv"}, routes: join(routes(native, "json", "yaml"), routes(office, "xlsx", "ods"))},
}

// defaults: the proposed target of each source, best first; the first
// available one is proposed (else the first, marked unavailable).
var defaults = map[string][]string{
	"jpg": {"png"}, "webp": {"png"}, "heic": {"jpg", "png"}, "avif": {"png"}, "bmp": {"png"},
	"tiff": {"png"}, "ico": {"png"}, "jxl": {"png"}, "tga": {"png"}, "psd": {"png"},
	"png": {"jpg"}, "svg": {"png"}, "gif": {"mp4", "webp"},
	"flac": {"mp3"}, "wav": {"mp3"}, "ogg": {"mp3"}, "opus": {"mp3"}, "m4a": {"mp3"},
	"aac": {"mp3"}, "aiff": {"mp3"}, "wma": {"mp3"}, "mp3": {"wav"},
	"mkv": {"mp4"}, "mov": {"mp4"}, "webm": {"mp4"}, "avi": {"mp4"}, "wmv": {"mp4"},
	"flv": {"mp4"}, "mpeg": {"mp4"}, "3gp": {"mp4"}, "mp4": {"webm"},
	"docx": {"pdf"}, "doc": {"pdf"}, "odt": {"pdf"}, "rtf": {"pdf"}, "txt": {"pdf"},
	"xlsx": {"pdf"}, "xls": {"pdf"}, "ods": {"pdf"}, "pptx": {"pdf"}, "ppt": {"pdf"}, "odp": {"pdf"},
	"md": {"pdf", "html"}, "html": {"pdf"}, "rst": {"pdf", "html"}, "org": {"pdf", "html"},
	"tex": {"pdf", "html"}, "epub": {"pdf", "docx"}, "pdf": {"docx", "png"},
	"json": {"yaml"}, "yaml": {"json"}, "toml": {"json"}, "csv": {"json"},
}

// popular: the targets shown first per source kind (the default always is).
var popular = map[Kind][]string{
	KindImage:    {"png", "jpg", "webp", "avif", "mp4", "pdf"},
	KindAudio:    {"mp3", "wav", "flac", "ogg"},
	KindVideo:    {"mp4", "webm", "gif", "mp3"},
	KindDocument: {"pdf", "docx", "png", "txt", "xlsx", "csv"},
	KindEbook:    {"pdf", "html", "docx", "epub", "md"},
	KindData:     {"json", "yaml", "csv", "toml"},
}

// routesFor merges the families of a source into one route per target.
func routesFor(from string) []route {
	var out []route
	seen := map[string]bool{from: true}
	for _, fam := range families {
		if !contains(fam.sources, from) {
			continue
		}
		for _, r := range fam.routes {
			if !seen[r.to] {
				seen[r.to] = true
				out = append(out, r)
			}
		}
	}
	return out
}

func contains(list []string, s string) bool {
	for _, x := range list {
		if x == s {
			return true
		}
	}
	return false
}

// Target is one conversion offered for a source.
type Target struct {
	ID        string `json:"id"`
	Label     string `json:"label"`
	Kind      Kind   `json:"kind"`
	Engine    Engine `json:"engine"`
	Available bool   `json:"available"`
	// Needs names the tool that would enable an unavailable target.
	Needs   string `json:"needs,omitempty"`
	Popular bool   `json:"popular"`
	Lossy   bool   `json:"lossy"`
}

// Targets lists the conversions of a source format on this machine, in
// table order. Unavailable ones stay listed with the tool they need.
func Targets(from string, t *Tools) []Target {
	src, ok := byID[from]
	if !ok {
		return nil
	}
	pop := map[string]bool{}
	for _, id := range popular[src.Kind] {
		pop[id] = true
	}
	if d := defaults[from]; len(d) > 0 {
		pop[d[0]] = true
	}
	var out []Target
	for _, r := range routesFor(from) {
		f := byID[r.to]
		tg := Target{ID: f.ID, Label: f.Label, Kind: f.Kind, Popular: pop[f.ID], Lossy: f.Lossy}
		tg.Engine, tg.Available = pick(r.via, from, r.to, t)
		if !tg.Available {
			tg.Needs = ToolName(tg.Engine)
		}
		out = append(out, tg)
	}
	return out
}

// pick returns the first installed engine that handles from -> to, else
// the first engine that would (to name what to install).
func pick(via []Engine, from, to string, t *Tools) (Engine, bool) {
	for _, e := range via {
		if t.Has(e) && t.supports(e, from, to) {
			return e, true
		}
	}
	for _, e := range via {
		if !t.Has(e) {
			return e, false
		}
	}
	return via[0], false
}

// Default is the proposed target of a source: the first available of its
// defaults, else the first one.
func Default(from string, t *Tools) string {
	d := defaults[from]
	if len(d) == 0 {
		return ""
	}
	targets := Targets(from, t)
	for _, id := range d {
		for _, tg := range targets {
			if tg.ID == id && tg.Available {
				return id
			}
		}
	}
	return d[0]
}

// Route returns the target entry of from -> to, or false when the pair is
// not a conversion the table knows.
func Route(from, to string, t *Tools) (Target, bool) {
	for _, tg := range Targets(from, t) {
		if tg.ID == to {
			return tg, true
		}
	}
	return Target{}, false
}
