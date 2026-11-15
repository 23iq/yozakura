package convert

import (
	"net/url"
	"path/filepath"
)

// LibreOffice runs on a private profile (see PlanOptions). A fresh profile
// has the defaults: pin what keeps a hostile office file inert, before the
// first run (LibreOffice keeps these items when it rewrites the file).
//   - macros never run (MacroSecurityLevel 3 = very high, execution off);
//   - links to other files and URLs (images, OLE, sections, DDE) are never
//     updated on load. Writer stores its UpdateLinks enum as is
//     (sw/inc/linkenum.hxx: NEVER = 0, MANUAL = 1, AUTOMATIC = 2; the
//     description in Writer.xcs saying "2 = never" is wrong), so Writer 0;
//     Calc's ScLkUpdMode is LM_ALWAYS = 0, LM_NEVER = 1, so Calc 1;
//   - documents cannot make LibreOffice follow untrusted referer links.
const officeRegistry = `<?xml version="1.0" encoding="UTF-8"?>
<oor:items xmlns:oor="http://openoffice.org/2001/registry" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
<item oor:path="/org.openoffice.Office.Common/Security/Scripting"><prop oor:name="MacroSecurityLevel" oor:op="fuse"><value>3</value></prop></item>
<item oor:path="/org.openoffice.Office.Common/Security/Scripting"><prop oor:name="DisableMacrosExecution" oor:op="fuse"><value>true</value></prop></item>
<item oor:path="/org.openoffice.Office.Common/Security/Scripting"><prop oor:name="BlockUntrustedRefererLinks" oor:op="fuse"><value>true</value></prop></item>
<item oor:path="/org.openoffice.Office.Writer/Content/Update"><prop oor:name="Link" oor:op="fuse"><value>0</value></prop></item>
<item oor:path="/org.openoffice.Office.Calc/Content/Update"><prop oor:name="Link" oor:op="fuse"><value>1</value></prop></item>
</oor:items>
`

// officeFiles: the settings written into a profile that lacks them.
func officeFiles(profile string) map[string]string {
	return map[string]string{filepath.Join(profile, "user", "registrymodifications.xcu"): officeRegistry}
}

// officeFilters: LibreOffice's --convert-to value per target.
var officeFilters = map[string]string{
	"pdf":  "pdf",
	"docx": "docx:MS Word 2007 XML",
	"doc":  "doc:MS Word 97",
	"odt":  "odt",
	"rtf":  "rtf",
	"txt":  "txt:Text (encoded):UTF8",
	"html": "html",
	"xlsx": "xlsx:Calc MS Excel 2007 XML",
	"ods":  "ods",
	"csv":  "csv:Text - txt - csv (StarCalc):44,34,76,1",
	"pptx": "pptx:Impress MS PowerPoint 2007 XML",
	"odp":  "odp",
}

func sofficeStep(prog, profile, from, to, src, out string) Step {
	profileURL := url.URL{Scheme: "file", Path: profile}
	args := []string{"--headless", "--norestore", "--nolockcheck", "--nologo", "--nodefault",
		"-env:UserInstallation=" + profileURL.String()}
	if from == "pdf" {
		args = append(args, "--infilter=writer_pdf_import")
	}
	args = append(args, "--convert-to", officeFilters[to], "--outdir", officeOut, src)
	return Step{Prog: prog, Args: args, Collect: officeOut, Out: out, Timeout: stepTimeouts[EngineSoffice]}
}
