package convert

import (
	"bytes"
	"encoding/csv"
	"encoding/json"
	"errors"
	"fmt"
	"math/big"
	"os"
	"regexp"
	"strings"

	"github.com/pelletier/go-toml/v2"
	"gopkg.in/yaml.v3"
)

// Data goes through a yaml.Node: it keeps the key order of json, yaml and
// csv (toml is read into a map, so its keys come out sorted).
func convertData(src, from, dst, to string) error {
	raw, err := os.ReadFile(src)
	if err != nil {
		return err
	}
	node, err := readData(raw, from)
	if err != nil {
		return err
	}
	out, err := writeData(node, to)
	if err != nil {
		return err
	}
	return os.WriteFile(dst, out, 0o644)
}

func readData(raw []byte, from string) (*yaml.Node, error) {
	var node yaml.Node
	switch from {
	case "json":
		if !json.Valid(raw) {
			return nil, errors.New("not valid JSON")
		}
		if err := yaml.Unmarshal(raw, &node); err != nil {
			return nil, fmt.Errorf("JSON: %w", err)
		}
		plainStyle(&node)
	case "yaml":
		if err := yaml.Unmarshal(raw, &node); err != nil {
			return nil, fmt.Errorf("YAML: %v", firstLine(err.Error()))
		}
	case "toml":
		var m map[string]any
		if err := toml.Unmarshal(raw, &m); err != nil {
			return nil, fmt.Errorf("TOML: %v", firstLine(err.Error()))
		}
		if err := node.Encode(m); err != nil {
			return nil, err
		}
		return &node, nil
	case "csv":
		return readCSV(raw)
	default:
		return nil, fmt.Errorf("%s is not a data format", label(from))
	}
	if node.Kind == 0 {
		return nil, errors.New("the file is empty")
	}
	if err := checkAliases(&node); err != nil {
		return nil, err
	}
	if node.Kind == yaml.DocumentNode && len(node.Content) == 1 {
		return node.Content[0], nil
	}
	return &node, nil
}

// Alias limits: a document whose aliases loop or expand past these sizes
// (a "billion laughs" file) is refused instead of filling memory.
const (
	maxExpandedNodes = 1_000_000
	maxDepth         = 1000
)

var errAliases = errors.New("the file's aliases loop or expand too much")

// checkAliases walks the node tree the way the writers expand it (an alias
// is its target again) and fails on an alias inside its own target or past
// maxExpandedNodes / maxDepth.
func checkAliases(root *yaml.Node) error {
	budget := maxExpandedNodes
	active := map[*yaml.Node]bool{}
	var walk func(n *yaml.Node, depth int) error
	walk = func(n *yaml.Node, depth int) error {
		budget--
		if budget < 0 || depth > maxDepth {
			return errAliases
		}
		if n.Kind == yaml.AliasNode {
			if n.Alias == nil || active[n.Alias] {
				return errAliases
			}
			n = n.Alias
		}
		if len(n.Content) == 0 {
			return nil
		}
		active[n] = true
		defer delete(active, n)
		for _, c := range n.Content {
			if err := walk(c, depth+1); err != nil {
				return err
			}
		}
		return nil
	}
	return walk(root, 0)
}

// plainStyle drops the flow / quoted styles a JSON source parses with, so
// the YAML written from it is block style.
func plainStyle(n *yaml.Node) {
	if n.Kind != yaml.ScalarNode || n.Tag != "!!str" {
		n.Style = 0
	} else if !strings.ContainsAny(n.Value, "\n") {
		n.Style = 0
	}
	for _, c := range n.Content {
		plainStyle(c)
	}
}

func readCSV(raw []byte) (*yaml.Node, error) {
	r := csv.NewReader(bytes.NewReader(bytes.TrimPrefix(raw, []byte("\ufeff"))))
	r.FieldsPerRecord = -1
	rows, err := r.ReadAll()
	if err != nil {
		return nil, fmt.Errorf("CSV: %v", err)
	}
	if len(rows) == 0 {
		return nil, errors.New("the file is empty")
	}
	header := rows[0]
	seq := &yaml.Node{Kind: yaml.SequenceNode, Tag: "!!seq"}
	for _, row := range rows[1:] {
		m := &yaml.Node{Kind: yaml.MappingNode, Tag: "!!map"}
		for i, h := range header {
			v := ""
			if i < len(row) {
				v = row[i]
			}
			m.Content = append(m.Content, strNode(h), strNode(v))
		}
		seq.Content = append(seq.Content, m)
	}
	return seq, nil
}

func strNode(s string) *yaml.Node {
	return &yaml.Node{Kind: yaml.ScalarNode, Tag: "!!str", Value: s}
}

func writeData(n *yaml.Node, to string) ([]byte, error) {
	switch to {
	case "json":
		var b bytes.Buffer
		if err := writeJSON(&b, n, ""); err != nil {
			return nil, err
		}
		b.WriteByte('\n')
		return b.Bytes(), nil
	case "yaml":
		quoteYAML11(n, map[*yaml.Node]bool{})
		var b bytes.Buffer
		enc := yaml.NewEncoder(&b)
		enc.SetIndent(2)
		if err := enc.Encode(n); err != nil {
			return nil, err
		}
		_ = enc.Close()
		return b.Bytes(), nil
	case "toml":
		var m map[string]any
		if n.Kind != yaml.MappingNode || n.Decode(&m) != nil {
			return nil, errors.New("TOML needs an object at the top")
		}
		out, err := toml.Marshal(m)
		if err != nil {
			return nil, fmt.Errorf("TOML: %v", firstLine(err.Error()))
		}
		return out, nil
	case "csv":
		return writeCSV(n)
	}
	return nil, fmt.Errorf("%s is not a data format", label(to))
}

// writeJSON writes n as indented JSON in its own key order.
func writeJSON(w *bytes.Buffer, n *yaml.Node, indent string) error {
	if n.Kind == yaml.AliasNode && n.Alias != nil {
		n = n.Alias
	}
	next := indent + "  "
	switch n.Kind {
	case yaml.DocumentNode:
		if len(n.Content) == 0 {
			w.WriteString("null")
			return nil
		}
		return writeJSON(w, n.Content[0], indent)
	case yaml.MappingNode:
		if len(n.Content) == 0 {
			w.WriteString("{}")
			return nil
		}
		w.WriteString("{\n")
		for i := 0; i+1 < len(n.Content); i += 2 {
			if i > 0 {
				w.WriteString(",\n")
			}
			k, _ := json.Marshal(n.Content[i].Value)
			w.WriteString(next)
			w.Write(k)
			w.WriteString(": ")
			if err := writeJSON(w, n.Content[i+1], next); err != nil {
				return err
			}
		}
		w.WriteString("\n" + indent + "}")
	case yaml.SequenceNode:
		if len(n.Content) == 0 {
			w.WriteString("[]")
			return nil
		}
		w.WriteString("[\n")
		for i, c := range n.Content {
			if i > 0 {
				w.WriteString(",\n")
			}
			w.WriteString(next)
			if err := writeJSON(w, c, next); err != nil {
				return err
			}
		}
		w.WriteString("\n" + indent + "]")
	default:
		// past int64 an integer resolves (and decodes) as a float:
		// 1.2345678901234568e+29; write its digits
		if n.Tag == "!!int" || (n.Tag == "!!float" && bigDigits.MatchString(n.Value)) {
			if i, ok := new(big.Int).SetString(strings.ReplaceAll(n.Value, "_", ""), 0); ok {
				w.WriteString(i.String())
				return nil
			}
		}
		var v any
		if err := n.Decode(&v); err != nil {
			return err
		}
		b, err := json.Marshal(v)
		if err != nil {
			return fmt.Errorf("JSON: %v", err)
		}
		w.Write(b)
	}
	return nil
}

// writeCSV needs a list of objects (or one object: one row); nested values
// are written as compact JSON. Columns: every key, in first-seen order.
func writeCSV(n *yaml.Node) ([]byte, error) {
	rows := []*yaml.Node{n}
	if n.Kind == yaml.SequenceNode {
		rows = n.Content
	}
	var header []string
	col := map[string]int{}
	for _, r := range rows {
		if r.Kind != yaml.MappingNode {
			return nil, errors.New("CSV needs a list of objects")
		}
		for i := 0; i+1 < len(r.Content); i += 2 {
			k := r.Content[i].Value
			if _, ok := col[k]; !ok {
				col[k] = len(header)
				header = append(header, k)
			}
		}
	}
	var b bytes.Buffer
	cw := csv.NewWriter(&b)
	_ = cw.Write(header)
	for _, r := range rows {
		rec := make([]string, len(header))
		for i := 0; i+1 < len(r.Content); i += 2 {
			v := r.Content[i+1]
			if v.Kind == yaml.ScalarNode {
				if v.Tag != "!!null" {
					rec[col[r.Content[i].Value]] = v.Value
				}
				continue
			}
			var nested bytes.Buffer
			if err := writeJSON(&nested, v, ""); err != nil {
				return nil, err
			}
			rec[col[r.Content[i].Value]] = compactJSON(nested.Bytes())
		}
		_ = cw.Write(rec)
	}
	cw.Flush()
	return b.Bytes(), cw.Error()
}

func compactJSON(b []byte) string {
	var out bytes.Buffer
	if json.Compact(&out, b) != nil {
		return string(b)
	}
	return out.String()
}

func firstLine(s string) string {
	if i := strings.IndexByte(s, '\n'); i >= 0 {
		return s[:i]
	}
	return s
}

// bigDigits is a decimal integer literal.
var bigDigits = regexp.MustCompile(`^[-+]?[0-9][0-9_]*$`)

// yaml11Base60 is a YAML 1.1 sexagesimal number (1:20 is 80 there).
var yaml11Base60 = regexp.MustCompile(`^[-+]?[0-9][0-9_]*(:[0-5]?[0-9])+(\.[0-9_]*)?$`)

// yaml11Special: plain strings a YAML 1.1 reader (PyYAML, many tools)
// takes for a bool or a number, though YAML 1.2 keeps them strings.
func yaml11Special(s string) bool {
	switch s {
	case "y", "Y", "yes", "Yes", "YES", "n", "N", "no", "No", "NO", "on", "On", "ON", "off", "Off", "OFF":
		return true
	}
	return yaml11Base60.MatchString(s)
}

// quoteYAML11 quotes the plain string scalars yaml11Special names, so the
// YAML written means the same to every reader.
func quoteYAML11(n *yaml.Node, seen map[*yaml.Node]bool) {
	if n == nil || seen[n] {
		return
	}
	seen[n] = true
	if n.Kind == yaml.ScalarNode && n.Style == 0 && (n.Tag == "!!str" || n.Tag == "") && yaml11Special(n.Value) {
		n.Style = yaml.DoubleQuotedStyle
	}
	for _, c := range n.Content {
		quoteYAML11(c, seen)
	}
}
