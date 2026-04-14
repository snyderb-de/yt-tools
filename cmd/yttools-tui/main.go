package main

import (
	"bufio"
	"context"
	"fmt"
	"io"
	"math"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"time"

	"github.com/charmbracelet/bubbles/viewport"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/huh"
	"github.com/charmbracelet/lipgloss"
)

var (
	speedPattern = regexp.MustCompile(`\sat\s+([0-9]+(?:\.[0-9]+)?)([KMG]?i?B/s|[KMG]?B/s)`)
	blocks       = []rune("▁▂▃▄▅▆▇█")
)

type configState struct {
	InputMode        string
	URL              string
	URLListFile      string
	Mode             string
	AudioFormat      string
	VideoFormat      string
	OutputDir        string
	FilenameTemplate string
	AuthMode         string
	Browser          string
	CookiesPath      string
}

type logLineMsg struct{ line string }
type speedSampleMsg struct{ mbps float64 }
type animTickMsg struct{}
type jobStartedMsg struct {
	index   int
	total   int
	url     string
	command string
}
type jobDoneMsg struct {
	index int
	total int
	url   string
	err   error
}
type batchDoneMsg struct {
	total     int
	success   int
	failed    int
	cancelled bool
}
type browserOpenMsg struct{ err error }

type model struct {
	width  int
	height int

	form   *huh.Form
	config configState

	viewport viewport.Model
	logs     []string

	running       bool
	cancel        context.CancelFunc
	status        string
	summary       string
	lastCommand   string
	currentJobURL string

	ytDlpPath  string
	ffmpegPath string
	nodePath   string

	events chan tea.Msg

	speedSamples []float64
	currentMbps  float64
	peakMbps     float64
	colorPhase   float64
}

func main() {
	m := newModel()
	program := tea.NewProgram(m, tea.WithAltScreen())
	if _, err := program.Run(); err != nil {
		fmt.Fprintf(os.Stderr, "tui error: %v\n", err)
		os.Exit(1)
	}
}

func newModel() model {
	home, _ := os.UserHomeDir()

	m := model{
		status:     "Ready",
		summary:    "Ctrl+R Run  •  Ctrl+X Cancel  •  Ctrl+L Open YouTube Login  •  Q Quit",
		events:     make(chan tea.Msg, 4096),
		logs:       []string{},
		ytDlpPath:  findTool("yt-dlp"),
		ffmpegPath: findTool("ffmpeg"),
		nodePath:   findTool("node"),
		config: configState{
			InputMode:        "single-url",
			URL:              "",
			URLListFile:      filepath.Join(home, "Desktop", "raelynn-list.text"),
			Mode:             "convert-to-audio",
			AudioFormat:      "mp3",
			VideoFormat:      "mp4",
			OutputDir:        filepath.Join(home, "Downloads", "YTTools"),
			FilenameTemplate: "%(title)s.%(ext)s",
			AuthMode:         "none",
			Browser:          "safari",
			CookiesPath:      "",
		},
	}

	m.viewport = viewport.New(80, 20)
	m.viewport.SetContent("")

	m.form = buildForm(&m.config)

	if m.ytDlpPath == "" {
		m.status = "yt-dlp missing"
		m.appendLog("ERROR: yt-dlp not found in PATH. Install with: brew install yt-dlp")
	} else {
		m.appendLog("Detected yt-dlp at " + m.ytDlpPath)
	}

	if m.ffmpegPath == "" {
		m.appendLog("WARNING: ffmpeg not found. Conversion modes may fail.")
	} else {
		m.appendLog("Detected ffmpeg at " + m.ffmpegPath)
	}

	if m.nodePath == "" {
		m.appendLog("WARNING: node not found. Some YouTube URLs may fail without JS runtime.")
	} else {
		m.appendLog("Detected node at " + m.nodePath)
	}

	m.appendLog("Ready. Use input mode 'url-list-file' for bulk jobs (one URL per line).")
	return m
}

func buildForm(cfg *configState) *huh.Form {
	return huh.NewForm(
		huh.NewGroup(
			huh.NewSelect[string]().
				Title("Input Mode").
				Options(
					huh.NewOption("Single URL", "single-url"),
					huh.NewOption("URL List File", "url-list-file"),
				).
				Value(&cfg.InputMode),
			huh.NewInput().
				Title("URL").
				Placeholder("https://www.youtube.com/watch?v=...").
				Value(&cfg.URL),
			huh.NewInput().
				Title("URL List File").
				Value(&cfg.URLListFile),
			huh.NewSelect[string]().
				Title("Mode").
				Options(
					huh.NewOption("Extract Audio Track", "extract-audio-track"),
					huh.NewOption("Convert to Audio", "convert-to-audio"),
					huh.NewOption("Convert Video Format", "convert-video-format"),
				).
				Value(&cfg.Mode),
			huh.NewSelect[string]().
				Title("Audio Format").
				Options(
					huh.NewOption("MP3", "mp3"),
					huh.NewOption("M4A", "m4a"),
					huh.NewOption("WAV", "wav"),
					huh.NewOption("FLAC", "flac"),
					huh.NewOption("OPUS", "opus"),
				).
				Value(&cfg.AudioFormat),
			huh.NewSelect[string]().
				Title("Video Format").
				Options(
					huh.NewOption("MP4", "mp4"),
					huh.NewOption("MKV", "mkv"),
					huh.NewOption("WEBM", "webm"),
					huh.NewOption("MOV", "mov"),
				).
				Value(&cfg.VideoFormat),
			huh.NewInput().
				Title("Output Directory").
				Value(&cfg.OutputDir),
			huh.NewInput().
				Title("Filename Template").
				Value(&cfg.FilenameTemplate),
			huh.NewSelect[string]().
				Title("Auth Mode").
				Options(
					huh.NewOption("None", "none"),
					huh.NewOption("Cookies from Browser", "cookies-from-browser"),
					huh.NewOption("Cookies File", "cookies-file"),
				).
				Value(&cfg.AuthMode),
			huh.NewSelect[string]().
				Title("Browser").
				Options(
					huh.NewOption("Safari", "safari"),
					huh.NewOption("Chrome", "chrome"),
					huh.NewOption("Firefox", "firefox"),
					huh.NewOption("Edge", "edge"),
					huh.NewOption("Brave", "brave"),
				).
				Value(&cfg.Browser),
			huh.NewInput().
				Title("cookies.txt Path").
				Value(&cfg.CookiesPath),
		),
	)
}

func (m model) Init() tea.Cmd {
	return tea.Batch(
		waitForWorker(m.events),
		animTickCmd(),
	)
}

func waitForWorker(ch <-chan tea.Msg) tea.Cmd {
	return func() tea.Msg {
		msg, ok := <-ch
		if !ok {
			return nil
		}
		return msg
	}
}

func animTickCmd() tea.Cmd {
	return tea.Tick(120*time.Millisecond, func(time.Time) tea.Msg {
		return animTickMsg{}
	})
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height
		m.resizeViewport()
		return m, nil
	case tea.KeyMsg:
		switch msg.String() {
		case "q", "ctrl+c":
			if m.running {
				m.requestCancel()
				return m, nil
			}
			return m, tea.Quit
		case "ctrl+r":
			if m.running {
				m.appendLog("A batch is already running.")
				return m, nil
			}
			if err := m.startBatch(); err != nil {
				m.status = "Input error"
				m.appendLog("ERROR: " + err.Error())
			}
			return m, nil
		case "ctrl+x":
			m.requestCancel()
			return m, nil
		case "ctrl+l":
			return m, openLoginCmd()
		}
	case logLineMsg:
		m.appendLog(msg.line)
		return m, waitForWorker(m.events)
	case speedSampleMsg:
		m.appendSpeed(msg.mbps)
		return m, waitForWorker(m.events)
	case animTickMsg:
		m.colorPhase += 0.23
		if m.colorPhase > 2*math.Pi {
			m.colorPhase -= 2 * math.Pi
		}
		return m, animTickCmd()
	case jobStartedMsg:
		m.status = fmt.Sprintf("Running %d/%d", msg.index, msg.total)
		m.currentJobURL = msg.url
		m.lastCommand = msg.command
		m.appendLog(fmt.Sprintf("[%d/%d] Processing: %s", msg.index, msg.total, msg.url))
		m.appendLog(msg.command)
		return m, waitForWorker(m.events)
	case jobDoneMsg:
		if msg.err == nil {
			m.appendLog(fmt.Sprintf("[%d/%d] Done", msg.index, msg.total))
		} else {
			m.appendLog(fmt.Sprintf("ERROR: [%d/%d] %s failed: %v", msg.index, msg.total, msg.url, msg.err))
		}
		return m, waitForWorker(m.events)
	case batchDoneMsg:
		m.running = false
		m.cancel = nil
		if msg.cancelled {
			m.status = "Cancelled"
			m.appendLog(fmt.Sprintf("Batch cancelled. Success: %d, Failed: %d", msg.success, msg.failed))
		} else if msg.failed > 0 {
			m.status = "Completed with errors"
			m.appendLog(fmt.Sprintf("Batch complete. Success: %d, Failed: %d", msg.success, msg.failed))
		} else {
			m.status = "Success"
			m.appendLog(fmt.Sprintf("Batch complete. Success: %d, Failed: %d", msg.success, msg.failed))
		}
		return m, waitForWorker(m.events)
	case browserOpenMsg:
		if msg.err != nil {
			m.appendLog("ERROR: cannot open browser: " + msg.err.Error())
		} else {
			m.appendLog("Opened YouTube login in browser.")
		}
		return m, nil
	}

	if !m.running {
		var cmd tea.Cmd
		formModel, formCmd := m.form.Update(msg)
		if updated, ok := formModel.(*huh.Form); ok {
			m.form = updated
		}
		if formCmd != nil {
			cmd = formCmd
		}

		vpModel, vpCmd := m.viewport.Update(msg)
		m.viewport = vpModel
		if cmd != nil && vpCmd != nil {
			return m, tea.Batch(cmd, vpCmd)
		}
		if cmd != nil {
			return m, cmd
		}
		if vpCmd != nil {
			return m, vpCmd
		}
		return m, nil
	}

	vpModel, vpCmd := m.viewport.Update(msg)
	m.viewport = vpModel
	return m, vpCmd
}

func (m *model) startBatch() error {
	if m.ytDlpPath == "" {
		return fmt.Errorf("yt-dlp not found in PATH")
	}

	urls, err := m.resolveInputURLs()
	if err != nil {
		return err
	}

	m.running = true
	m.status = "Running"
	m.currentJobURL = ""
	m.speedSamples = nil
	m.currentMbps = 0
	m.peakMbps = 0
	m.appendLog("")
	m.appendLog(fmt.Sprintf("---\nStarting batch with %d URL(s)", len(urls)))

	ctx, cancel := context.WithCancel(context.Background())
	m.cancel = cancel

	cfg := m.config
	ytDlpPath := m.ytDlpPath
	ffmpegPath := m.ffmpegPath
	nodePath := m.nodePath
	events := m.events

	go runBatchWorker(ctx, events, ytDlpPath, ffmpegPath, nodePath, cfg, urls)
	return nil
}

func runBatchWorker(
	ctx context.Context,
	events chan<- tea.Msg,
	ytDlpPath string,
	ffmpegPath string,
	nodePath string,
	cfg configState,
	urls []string,
) {
	total := len(urls)
	success := 0
	failed := 0
	cancelled := false

	for idx, url := range urls {
		if ctx.Err() != nil {
			cancelled = true
			break
		}

		args, err := buildArgs(cfg, url, ffmpegPath, nodePath)
		command := ytDlpPath + " " + strings.Join(shellEscapeSlice(args), " ")
		events <- jobStartedMsg{index: idx + 1, total: total, url: url, command: command}
		if err != nil {
			failed++
			events <- jobDoneMsg{index: idx + 1, total: total, url: url, err: err}
			continue
		}

		if err := runSingleJob(ctx, events, ytDlpPath, args); err != nil {
			if ctx.Err() != nil {
				cancelled = true
				break
			}
			failed++
			events <- jobDoneMsg{index: idx + 1, total: total, url: url, err: err}
			continue
		}

		success++
		events <- jobDoneMsg{index: idx + 1, total: total, url: url, err: nil}
	}

	events <- batchDoneMsg{
		total:     total,
		success:   success,
		failed:    failed,
		cancelled: cancelled,
	}
}

func runSingleJob(ctx context.Context, events chan<- tea.Msg, ytDlpPath string, args []string) error {
	cmd := exec.CommandContext(ctx, ytDlpPath, args...)

	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return err
	}
	stderr, err := cmd.StderrPipe()
	if err != nil {
		return err
	}

	if err := cmd.Start(); err != nil {
		return fmt.Errorf("failed to start yt-dlp: %w", err)
	}

	done := make(chan struct{}, 2)
	go streamOutput(events, stdout, done)
	go streamOutput(events, stderr, done)

	waitErr := cmd.Wait()
	<-done
	<-done

	if ctx.Err() != nil {
		return ctx.Err()
	}
	return waitErr
}

func streamOutput(events chan<- tea.Msg, reader io.Reader, done chan<- struct{}) {
	defer func() { done <- struct{}{} }()

	scanner := bufio.NewScanner(reader)
	buf := make([]byte, 0, 1024*64)
	scanner.Buffer(buf, 1024*1024)
	for scanner.Scan() {
		line := scanner.Text()
		events <- logLineMsg{line: line}
		if mbps, ok := parseSpeedMbps(line); ok {
			events <- speedSampleMsg{mbps: mbps}
		}
	}
	if err := scanner.Err(); err != nil {
		events <- logLineMsg{line: "WARN: log stream error: " + err.Error()}
	}
}

func buildArgs(cfg configState, url string, ffmpegPath string, nodePath string) ([]string, error) {
	outputDir := strings.TrimSpace(cfg.OutputDir)
	if outputDir == "" {
		return nil, fmt.Errorf("output directory is required")
	}
	if err := os.MkdirAll(outputDir, 0o755); err != nil {
		return nil, fmt.Errorf("failed to create output directory: %w", err)
	}

	template := strings.TrimSpace(cfg.FilenameTemplate)
	if template == "" {
		return nil, fmt.Errorf("filename template is required")
	}

	args := []string{
		"--newline",
		"--progress",
		"--no-playlist",
		"-P", outputDir,
		"-o", template,
		"--no-mtime",
	}

	if ffmpegPath != "" {
		args = append(args, "--ffmpeg-location", ffmpegPath)
	}
	if nodePath != "" {
		args = append(args, "--js-runtimes", "node")
	}

	switch cfg.AuthMode {
	case "none":
	case "cookies-from-browser":
		args = append(args, "--cookies-from-browser", cfg.Browser)
	case "cookies-file":
		if strings.TrimSpace(cfg.CookiesPath) == "" {
			return nil, fmt.Errorf("cookies.txt path is required when auth mode is cookies-file")
		}
		args = append(args, "--cookies", strings.TrimSpace(cfg.CookiesPath))
	default:
		return nil, fmt.Errorf("unsupported auth mode: %s", cfg.AuthMode)
	}

	switch cfg.Mode {
	case "extract-audio-track":
		args = append(args, "-f", "bestaudio/best")
	case "convert-to-audio":
		args = append(args, "-x", "--audio-format", cfg.AudioFormat, "--audio-quality", "0", "-f", "bestaudio/best")
	case "convert-video-format":
		args = append(args, "--recode-video", cfg.VideoFormat, "-f", "bv*+ba/b")
	default:
		return nil, fmt.Errorf("unsupported mode: %s", cfg.Mode)
	}

	args = append(args, url)
	return args, nil
}

func (m *model) resolveInputURLs() ([]string, error) {
	switch m.config.InputMode {
	case "single-url":
		url := strings.TrimSpace(m.config.URL)
		if !isHTTPURL(url) {
			return nil, fmt.Errorf("enter a valid URL (http/https)")
		}
		return []string{url}, nil
	case "url-list-file":
		path := strings.TrimSpace(m.config.URLListFile)
		if path == "" {
			return nil, fmt.Errorf("URL list file path is required")
		}
		return loadURLsFromFile(path)
	default:
		return nil, fmt.Errorf("unsupported input mode: %s", m.config.InputMode)
	}
}

func loadURLsFromFile(path string) ([]string, error) {
	content, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("failed to read URL list file: %w", err)
	}

	lines := strings.Split(string(content), "\n")
	urls := make([]string, 0, len(lines))
	for _, line := range lines {
		value := strings.TrimSpace(line)
		if value == "" || strings.HasPrefix(value, "#") {
			continue
		}
		if !isHTTPURL(value) {
			return nil, fmt.Errorf("invalid URL in list file: %s", value)
		}
		urls = append(urls, value)
	}

	if len(urls) == 0 {
		return nil, fmt.Errorf("no URLs found in list file")
	}

	return urls, nil
}

func (m *model) requestCancel() {
	if !m.running {
		m.appendLog("No running job to cancel.")
		return
	}
	if m.cancel != nil {
		m.cancel()
	}
	m.status = "Cancelling"
	m.appendLog("Cancellation requested.")
}

func openLoginCmd() tea.Cmd {
	return func() tea.Msg {
		err := exec.Command("open", "https://accounts.google.com/ServiceLogin?service=youtube").Start()
		return browserOpenMsg{err: err}
	}
}

func (m *model) appendLog(line string) {
	m.logs = append(m.logs, line)
	if len(m.logs) > 3000 {
		m.logs = m.logs[len(m.logs)-2000:]
	}
	m.viewport.SetContent(strings.Join(m.logs, "\n"))
	m.viewport.GotoBottom()
}

func (m *model) appendSpeed(mbps float64) {
	if mbps <= 0 {
		return
	}

	smoothed := mbps
	if len(m.speedSamples) > 0 {
		last := m.speedSamples[len(m.speedSamples)-1]
		const alpha = 0.28
		smoothed = (alpha * mbps) + ((1 - alpha) * last)
	}

	m.currentMbps = smoothed
	if smoothed > m.peakMbps {
		m.peakMbps = smoothed
	}
	m.speedSamples = append(m.speedSamples, smoothed)
	if len(m.speedSamples) > 180 {
		m.speedSamples = m.speedSamples[len(m.speedSamples)-180:]
	}
}

func parseSpeedMbps(line string) (float64, bool) {
	match := speedPattern.FindStringSubmatch(line)
	if len(match) != 3 {
		return 0, false
	}
	value, err := strconv.ParseFloat(match[1], 64)
	if err != nil {
		return 0, false
	}
	unit := strings.ToUpper(strings.TrimSpace(match[2]))

	multiplier := 1.0
	switch unit {
	case "B/S":
		multiplier = 1
	case "KB/S", "KIB/S":
		multiplier = 1024
	case "MB/S", "MIB/S":
		multiplier = 1024 * 1024
	case "GB/S", "GIB/S":
		multiplier = 1024 * 1024 * 1024
	default:
		return 0, false
	}

	bytesPerSec := value * multiplier
	mbps := (bytesPerSec * 8.0) / 1_000_000.0
	if mbps < 0 {
		return 0, false
	}
	return mbps, true
}

func (m *model) resizeViewport() {
	bottomHeight := max(12, int(float64(m.height)*0.42))
	graphHeight := 7
	contentHeight := bottomHeight - graphHeight - 6
	if contentHeight < 4 {
		contentHeight = 4
	}
	contentWidth := m.width - 8
	if contentWidth < 20 {
		contentWidth = 20
	}
	m.viewport.Width = contentWidth
	m.viewport.Height = contentHeight
}

func (m model) View() string {
	if m.width == 0 || m.height == 0 {
		return "Loading..."
	}

	topHeight := max(16, int(float64(m.height)*0.48))
	bottomHeight := m.height - topHeight - 3
	if bottomHeight < 12 {
		bottomHeight = 12
	}

	title := titleStyle.Render("YT Tools • Charm TUI")
	status := statusStyle.Render("Status: " + m.status)
	help := helpStyle.Render(m.summary)

	headline := lipgloss.JoinHorizontal(lipgloss.Top, title, "   ", status)
	meta := lipgloss.JoinHorizontal(lipgloss.Top,
		metaStyle.Render("yt-dlp: "+displayOrMissing(m.ytDlpPath)),
		"    ",
		metaStyle.Render("ffmpeg: "+displayOrMissing(m.ffmpegPath)),
		"    ",
		metaStyle.Render("node: "+displayOrMissing(m.nodePath)),
	)

	command := m.lastCommand
	if command == "" {
		command = "No command yet. Press Ctrl+R to start."
	}

	topContent := strings.Join([]string{
		headline,
		help,
		meta,
		"",
		m.form.View(),
		"",
		labelStyle.Render("Last Command"),
		commandStyle.Width(max(20, m.width-10)).Render(command),
	}, "\n")

	topPanel := panelStyle.Height(topHeight).Render(topContent)

	graph := m.renderSpeedGraph(max(24, m.width-14))
	current := metricStyle.Render(fmt.Sprintf("Current %.2f Mbps", m.currentMbps))
	peak := metricStyle.Render(fmt.Sprintf("Peak %.2f Mbps", m.peakMbps))
	job := metricStyle.Render("Job: " + truncate(m.currentJobURL, 46))
	graphHeader := lipgloss.JoinHorizontal(lipgloss.Top, current, "   ", peak, "   ", job)

	m.resizeViewport()
	logsPanel := panelStyle.Height(bottomHeight).Render(strings.Join([]string{
		labelStyle.Render("Network Throughput"),
		graphHeader,
		graph,
		"",
		labelStyle.Render("Logs"),
		m.viewport.View(),
	}, "\n"))

	return rootStyle.Render(lipgloss.JoinVertical(lipgloss.Left, topPanel, "", logsPanel))
}

func (m model) renderSpeedGraph(width int) string {
	if width < 10 {
		return graphStyle.Render("No graph space")
	}
	if len(m.speedSamples) == 0 {
		return graphStyle.Render("Waiting for download activity...")
	}

	samples := m.speedSamples
	if len(samples) > width {
		samples = samples[len(samples)-width:]
	}

	peak := maxFloat(samples)
	if peak <= 0 {
		peak = 1
	}

	var b strings.Builder
	palette := []string{"45", "51", "87", "123", "159", "123", "87", "51"}
	for i, sample := range samples {
		norm := sample / peak
		if norm < 0 {
			norm = 0
		}
		if norm > 1 {
			norm = 1
		}
		idx := int(math.Round(norm * float64(len(blocks)-1)))
		if idx < 0 {
			idx = 0
		}
		if idx >= len(blocks) {
			idx = len(blocks) - 1
		}
		phaseOffset := (float64(i) / float64(max(1, len(samples)-1))) + (m.colorPhase / (2 * math.Pi))
		colorIdx := int(math.Mod(phaseOffset*float64(len(palette)), float64(len(palette))))
		if colorIdx < 0 {
			colorIdx = 0
		}
		if colorIdx >= len(palette) {
			colorIdx = len(palette) - 1
		}
		cell := lipgloss.NewStyle().
			Foreground(lipgloss.Color(palette[colorIdx])).
			Bold(true).
			Render(string(blocks[idx]))
		b.WriteString(cell)
	}

	graphLine := b.String()
	graphLine = graphGlowStyle.Render(graphLine)

	axis := axisStyle.Render(strings.Repeat("─", max(8, width)))
	return graphStyle.Width(width + 2).Render(graphLine + "\n" + axis)
}

func isHTTPURL(value string) bool {
	return strings.HasPrefix(value, "https://") || strings.HasPrefix(value, "http://")
}

func truncate(value string, maxLen int) string {
	v := strings.TrimSpace(value)
	if v == "" {
		return "-"
	}
	if len(v) <= maxLen {
		return v
	}
	if maxLen <= 3 {
		return v[:maxLen]
	}
	return v[:maxLen-3] + "..."
}

func maxFloat(values []float64) float64 {
	if len(values) == 0 {
		return 0
	}
	m := values[0]
	for _, v := range values[1:] {
		if v > m {
			m = v
		}
	}
	return m
}

func max(a, b int) int {
	if a > b {
		return a
	}
	return b
}

func shellEscapeSlice(values []string) []string {
	out := make([]string, 0, len(values))
	for _, v := range values {
		out = append(out, shellEscape(v))
	}
	return out
}

func shellEscape(v string) string {
	if v == "" {
		return "''"
	}
	if !strings.ContainsAny(v, " \t\n\"'\\") {
		return v
	}
	replaced := strings.ReplaceAll(v, "'", "'\"'\"'")
	return "'" + replaced + "'"
}

func displayOrMissing(path string) string {
	if path == "" {
		return "missing"
	}
	return path
}

func findTool(name string) string {
	if resolved, err := exec.LookPath(name); err == nil {
		return resolved
	}

	paths := []string{
		"/opt/homebrew/bin",
		"/usr/local/bin",
		"/usr/bin",
		"/bin",
		"/opt/homebrew/opt/yt-dlp/bin",
		"/opt/homebrew/opt/ffmpeg/bin",
	}

	for _, base := range paths {
		candidate := filepath.Join(base, name)
		if info, err := os.Stat(candidate); err == nil && info.Mode().Perm()&0o111 != 0 {
			return candidate
		}
	}
	return ""
}

var (
	rootStyle = lipgloss.NewStyle().
			Padding(1, 2).
			Foreground(lipgloss.Color("252"))

	panelStyle = lipgloss.NewStyle().
			Border(lipgloss.RoundedBorder()).
			BorderForeground(lipgloss.Color("63")).
			Padding(1, 2)

	titleStyle = lipgloss.NewStyle().
			Bold(true).
			Foreground(lipgloss.Color("205"))

	statusStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("86")).
			Bold(true)

	helpStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("245"))

	metaStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("250"))

	labelStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("81")).
			Bold(true)

	commandStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("252")).
			Border(lipgloss.NormalBorder()).
			BorderForeground(lipgloss.Color("238")).
			Padding(0, 1)

	metricStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("117")).
			Bold(true)

	graphStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("159"))

	graphGlowStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("45")).
			Bold(true)

	axisStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("239"))
)
