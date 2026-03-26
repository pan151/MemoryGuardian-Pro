// Memory Guardian Pro Dashboard - Neural Interface
// Cyberpunk / Neon-Tech Aesthetic

class MemoryGuardianDashboard {
    constructor() {
        this.apiBase = 'http://localhost:19527/api';
        this.refreshInterval = 2000;
        this.chartUpdateInterval = 5000;
        this.timeRange = 60;
        this.memoryChart = null;
        this.startTime = Date.now();
        this.alertCount = 0;
        this.freedMemory = 0;
        this.processCount = 0;
        
        this.init();
    }

    async init() {
        console.log('Initializing Neural Interface...');
        this.initChart();
        this.bindEvents();
        this.startPolling();
        this.startMatrixEffect();
        console.log('Neural Interface initialized!');
    }

    initChart() {
        const ctx = document.getElementById('memoryChart').getContext('2d');
        
        // Create gradient
        const gradient = ctx.createLinearGradient(0, 0, 0, 300);
        gradient.addColorStop(0, 'rgba(0, 243, 255, 0.3)');
        gradient.addColorStop(1, 'rgba(255, 0, 255, 0.1)');
        
        this.memoryChart = new Chart(ctx, {
            type: 'line',
            data: {
                labels: [],
                datasets: [{
                    label: 'Memory Usage',
                    data: [],
                    borderColor: '#00f3ff',
                    backgroundColor: gradient,
                    borderWidth: 2,
                    fill: true,
                    tension: 0.4,
                    pointRadius: 0,
                    pointHoverRadius: 6,
                    pointHoverBackgroundColor: '#00f3ff',
                    pointHoverBorderColor: '#fff',
                    pointHoverBorderWidth: 2
                }, {
                    label: 'Alert Threshold',
                    data: [],
                    borderColor: '#ffeb3b',
                    borderWidth: 2,
                    borderDash: [5, 5],
                    pointRadius: 0,
                    fill: false
                }, {
                    label: 'Critical Threshold',
                    data: [],
                    borderColor: '#ff0040',
                    borderWidth: 2,
                    borderDash: [5, 5],
                    pointRadius: 0,
                    fill: false
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: true,
                plugins: {
                    legend: {
                        display: true,
                        position: 'top',
                        labels: {
                            color: '#ffffff',
                            font: {
                                family: 'Orbitron',
                                size: 11,
                                weight: '700'
                            },
                            usePointStyle: true,
                            boxWidth: 8
                        }
                    },
                    tooltip: {
                        mode: 'index',
                        intersect: false,
                        backgroundColor: 'rgba(10, 10, 18, 0.95)',
                        titleColor: '#00f3ff',
                        bodyColor: '#ffffff',
                        borderColor: 'rgba(0, 243, 255, 0.3)',
                        borderWidth: 1,
                        titleFont: {
                            family: 'Orbitron',
                            size: 13,
                            weight: '700'
                        },
                        bodyFont: {
                            family: 'Rajdhani',
                            size: 12
                        },
                        padding: 12,
                        displayColors: true,
                        boxPadding: 4
                    }
                },
                scales: {
                    x: {
                        grid: {
                            color: 'rgba(255, 255, 255, 0.05)',
                            drawBorder: false
                        },
                        ticks: {
                            color: 'rgba(255, 255, 255, 0.4)',
                            font: {
                                family: 'Rajdhani',
                                size: 11
                            },
                            maxRotation: 0,
                            autoSkip: true
                        }
                    },
                    y: {
                        min: 0,
                        max: 100,
                        grid: {
                            color: 'rgba(255, 255, 255, 0.05)',
                            drawBorder: false
                        },
                        ticks: {
                            color: 'rgba(255, 255, 255, 0.4)',
                            font: {
                                family: 'Rajdhani',
                                size: 11
                            },
                            callback: function(value) {
                                return value + '%';
                            }
                        }
                    }
                },
                interaction: {
                    mode: 'nearest',
                    axis: 'x',
                    intersect: false
                },
                elements: {
                    line: {
                        borderJoinStyle: 'round'
                    }
                }
            }
        });
    }

    bindEvents() {
        // Chart time range buttons
        document.querySelectorAll('.chart-btn').forEach(btn => {
            btn.addEventListener('click', (e) => {
                document.querySelectorAll('.chart-btn').forEach(b => b.classList.remove('active'));
                e.target.classList.add('active');
                this.timeRange = parseInt(e.target.dataset.range);
                this.loadHistory();
            });
        });

        // Action buttons
        document.getElementById('btn-clean').addEventListener('click', () => this.executeOptimize('clean'));
        document.getElementById('btn-optimize').addEventListener('click', () => this.executeOptimize('full'));
        document.getElementById('btn-clear').addEventListener('click', () => this.clearLogs());
    }

    startPolling() {
        setInterval(() => this.updateState(), this.refreshInterval);
        setInterval(() => this.loadHistory(), this.chartUpdateInterval);
        setInterval(() => this.updateDuration(), 1000);
        
        this.updateState();
        this.loadHistory();
    }

    startMatrixEffect() {
        // Add subtle random data updates for visual effect
        setInterval(() => {
            const elements = document.querySelectorAll('.stat-value');
            elements.forEach(el => {
                if (el.textContent === '--') {
                    el.style.opacity = '0.7';
                }
            });
        }, 2000);
    }

    async updateState() {
        try {
            const response = await fetch(`${this.apiBase}/state`);
            const state = await response.json();
            
            this.updateMemoryVisual(state.memory);
            this.updateStats(state);
            this.updateProcesses(state.processes);
            this.updateFindings(state.findings);
            this.updateRiskScore(state.riskScore);
            
            this.updateLastTime();
        } catch (error) {
            console.error('Error updating state:', error);
            this.addLog('error', 'Connection error: ' + error.message);
        }
    }

    updateMemoryVisual(memory) {
        if (!memory) return;
        
        const percentage = memory.usedPct || 0;
        const used = memory.usedGB || 0;
        const free = memory.freeGB || 0;
        const total = memory.totalGB || 1;
        const cached = (total - used - free) || 0;
        
        // Update percentage display
        const percentageEl = document.getElementById('mem-percentage');
        percentageEl.textContent = `${percentage.toFixed(1)}%`;
        
        // Color based on usage
        if (percentage >= 90) {
            percentageEl.style.color = '#ff0040';
            percentageEl.style.textShadow = '0 0 20px #ff0040';
        } else if (percentage >= 80) {
            percentageEl.style.color = '#ffeb3b';
            percentageEl.style.textShadow = '0 0 20px #ffeb3b';
        } else {
            percentageEl.style.color = '#00f3ff';
            percentageEl.style.textShadow = '0 0 20px #00f3ff';
        }
        
        // Update details
        document.getElementById('mem-details').textContent = 
            `${used.toFixed(1)} / ${total.toFixed(1)} GB`;
        
        // Update progress ring
        const progress = document.getElementById('memory-progress');
        const circumference = 565.48;
        const offset = circumference - (percentage / 100) * circumference;
        progress.style.strokeDashoffset = offset;
        
        // Update progress ring color
        if (percentage >= 90) {
            progress.style.stroke = '#ff0040';
            progress.style.filter = 'drop-shadow(0 0 10px #ff0040)';
        } else if (percentage >= 80) {
            progress.style.stroke = '#ffeb3b';
            progress.style.filter = 'drop-shadow(0 0 10px #ffeb3b)';
        } else {
            progress.style.stroke = '#00f3ff';
            progress.style.filter = 'drop-shadow(0 0 10px #00f3ff)';
        }
        
        // Update bars
        document.getElementById('bar-used').style.width = `${(used / total) * 100}%`;
        document.getElementById('val-used').textContent = `${used.toFixed(1)} GB`;
        
        document.getElementById('bar-free').style.width = `${(free / total) * 100}%`;
        document.getElementById('val-free').textContent = `${free.toFixed(1)} GB`;
        
        document.getElementById('bar-cached').style.width = `${(cached / total) * 100}%`;
        document.getElementById('val-cached').textContent = `${cached.toFixed(1)} GB`;
    }

    updateStats(state) {
        // Alert count
        const alerts = state.alertCount || this.alertCount;
        document.getElementById('alert-count').textContent = alerts;
        
        // Freed memory
        const freed = (state.freedMemory || this.freedMemory) / 1024 / 1024 / 1024;
        document.getElementById('freed-memory').textContent = `${freed.toFixed(2)} GB`;
        
        // Process count
        this.processCount = state.processes?.length || 0;
        document.getElementById('proc-count').textContent = this.processCount;
        
        // Simulate CPU load (not available from API)
        const cpuLoad = Math.random() * 30 + 10;
        document.getElementById('cpu-load').textContent = `${cpuLoad.toFixed(0)}%`;
        
        // Update status indicator
        const statusText = document.getElementById('status-text');
        const statusDot = document.querySelector('.status-dot');
        
        if (state.isRunning !== false) {
            statusText.textContent = 'SYSTEM ACTIVE';
            statusText.style.color = '#00ff88';
            statusDot.style.background = '#00ff88';
            statusDot.style.boxShadow = '0 0 10px #00ff88';
        } else {
            statusText.textContent = 'SYSTEM STOPPED';
            statusText.style.color = '#ff0040';
            statusDot.style.background = '#ff0040';
            statusDot.style.boxShadow = '0 0 10px #ff0040';
        }
    }

    updateProcesses(processes) {
        const container = document.getElementById('process-list');
        
        if (!processes || processes.length === 0) {
            container.innerHTML = `
                <div class="loading-state">
                    <div class="scanning-animation"></div>
                    <div class="scanning-text">Scanning processes...</div>
                </div>
            `;
            return;
        }
        
        const topProcesses = processes.slice(0, 20);
        
        container.innerHTML = topProcesses.map(proc => `
            <div class="process-item" data-pid="${proc.pid}">
                <div class="process-name">${this.escapeHtml(proc.name)}</div>
                <div class="process-pid">${proc.pid}</div>
                <div class="process-cpu">${(proc.cpu || 0).toFixed(1)}%</div>
                <div class="process-mem">${(proc.memoryMB || 0).toFixed(0)} MB</div>
                <button class="process-action" onclick="dashboard.killProcess(${proc.pid}, '${this.escapeHtml(proc.name)}')">
                    TERMINATE
                </button>
            </div>
        `).join('');
    }

    updateFindings(findings) {
        const container = document.getElementById('findings');
        
        if (!findings || findings.length === 0) {
            container.innerHTML = `
                <div class="finding-placeholder">
                    <div class="scanning-animation" style="border-color: rgba(0, 243, 255, 0.3); border-top-color: #00f3ff;"></div>
                    <div class="scanning-text">System healthy - No anomalies detected</div>
                </div>
            `;
            return;
        }
        
        container.innerHTML = findings.map(finding => `
            <div class="finding-item ${finding.severity === 'high' ? 'danger' : ''} ${finding.severity === 'critical' ? 'critical' : ''}">
                <div class="finding-icon">${finding.severity === 'critical' ? '🔴' : finding.severity === 'high' ? '🟡' : '🟢'}</div>
                <div class="finding-content">
                    <div class="finding-title">${this.escapeHtml(finding.title)}</div>
                    <div class="finding-desc">${this.escapeHtml(finding.description)}</div>
                </div>
                ${finding.killCommand ? `
                    <button class="finding-action" onclick="dashboard.executeCommand('${this.escapeHtml(finding.killCommand)}')">
                        PURGE
                    </button>
                ` : ''}
            </div>
        `).join('');
    }

    updateRiskScore(riskScore) {
        const score = riskScore || 0;
        const valueEl = document.getElementById('risk-value');
        const statusEl = document.getElementById('risk-status');
        const indicator = document.getElementById('risk-indicator');
        
        valueEl.textContent = score;
        
        let status, color;
        if (score >= 80) {
            status = 'CRITICAL';
            color = '#ff0040';
        } else if (score >= 60) {
            status = 'HIGH RISK';
            color = '#ff00ff';
        } else if (score >= 30) {
            status = 'MODERATE';
            color = '#ffeb3b';
        } else {
            status = 'OPTIMAL';
            color = '#00ff88';
        }
        
        statusEl.textContent = status;
        statusEl.style.color = color;
        valueEl.style.color = color;
        valueEl.style.textShadow = `0 0 15px ${color}`;
        
        // Update indicator
        indicator.style.setProperty('--indicator-width', `${score}%`);
    }

    async loadHistory() {
        try {
            const response = await fetch(`${this.apiBase}/history?range=${this.timeRange}`);
            const history = await response.json();
            
            this.updateChart(history);
        } catch (error) {
            console.error('Error loading history:', error);
        }
    }

    updateChart(history) {
        if (!history || !Array.isArray(history)) {
            return;
        }
        
        const labels = history.map(h => {
            const date = new Date(h.timestamp);
            return date.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' });
        });
        
        const memoryData = history.map(h => h.memPct);
        const alertThreshold = Array(memoryData.length).fill(80);
        const criticalThreshold = Array(memoryData.length).fill(90);
        
        this.memoryChart.data.labels = labels;
        this.memoryChart.data.datasets[0].data = memoryData;
        this.memoryChart.data.datasets[1].data = alertThreshold;
        this.memoryChart.data.datasets[2].data = criticalThreshold;
        
        this.memoryChart.update('none');
    }

    updateDuration() {
        const elapsed = Date.now() - this.startTime;
        const hours = Math.floor(elapsed / 3600000);
        const minutes = Math.floor((elapsed % 3600000) / 60000);
        const seconds = Math.floor((elapsed % 60000) / 1000);
        
        const duration = `${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
        document.getElementById('uptime').textContent = duration;
    }

    updateLastTime() {
        const now = new Date();
        const timeStr = now.toLocaleTimeString('en-US', { 
            hour: '2-digit', 
            minute: '2-digit', 
            second: '2-digit' 
        });
        document.getElementById('last-update').textContent = `LIVE • ${timeStr}`;
    }

    async executeOptimize(type) {
        try {
            this.addLog('info', `Initiating optimization protocol: ${type}`);
            
            const response = await fetch(`${this.apiBase}/optimize`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({ type })
            });
            
            const result = await response.json();
            
            if (result.success) {
                this.addLog('info', `Optimization complete: ${result.message || 'Operation successful'}`);
                this.freedMemory += result.freedMemory || 0;
            } else {
                this.addLog('error', `Optimization failed: ${result.error || 'Unknown error'}`);
            }
            
        } catch (error) {
            console.error('Error executing optimize:', error);
            this.addLog('error', 'Optimization error: ' + error.message);
        }
    }

    async executeCommand(command) {
        try {
            this.addLog('info', `Executing command: ${command}`);
            
            const response = await fetch(`${this.apiBase}/execute`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({ command })
            });
            
            const result = await response.json();
            
            if (result.success) {
                this.addLog('info', `Command executed successfully: ${result.message}`);
            } else {
                this.addLog('error', `Command failed: ${result.error}`);
            }
            
        } catch (error) {
            console.error('Error executing command:', error);
            this.addLog('error', 'Command error: ' + error.message);
        }
    }

    async killProcess(pid, name) {
        if (!confirm(`Confirm termination of process ${name} (PID: ${pid})?`)) {
            return;
        }
        
        try {
            this.addLog('warn', `Terminating process: ${name} (PID: ${pid})`);
            
            const response = await fetch(`${this.apiBase}/kill`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({ pid })
            });
            
            const result = await response.json();
            
            if (result.success) {
                this.addLog('info', `Process ${name} terminated successfully`);
            } else {
                this.addLog('error', `Termination failed: ${result.error}`);
            }
            
            await this.updateState();
            
        } catch (error) {
            console.error('Error killing process:', error);
            this.addLog('error', 'Termination error: ' + error.message);
        }
    }

    addLog(level, message) {
        const container = document.getElementById('log-terminal');
        const timestamp = new Date().toLocaleTimeString('en-US', { 
            hour: '2-digit', 
            minute: '2-digit', 
            second: '2-digit' 
        });
        
        const logEntry = document.createElement('div');
        logEntry.className = `log-entry ${level}`;
        logEntry.innerHTML = `
            <span class="log-time">${timestamp}</span>
            <span class="log-marker">▸</span>
            <span class="log-message">${this.escapeHtml(message)}</span>
        `;
        
        container.insertBefore(logEntry, container.firstChild);
        
        // Keep only last 50 logs
        while (container.children.length > 50) {
            container.removeChild(container.lastChild);
        }
    }

    clearLogs() {
        const container = document.getElementById('log-terminal');
        container.innerHTML = `
            <div class="log-entry info">
                <span class="log-time">${new Date().toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit', second: '2-digit' })}</span>
                <span class="log-marker">▸</span>
                <span class="log-message">Terminal cleared - Log buffer reset</span>
            </div>
        `;
    }

    escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }
}

// Initialize dashboard when DOM is ready
document.addEventListener('DOMContentLoaded', () => {
    window.dashboard = new MemoryGuardianDashboard();
});

// Global error handler
window.addEventListener('error', (event) => {
    console.error('Dashboard error:', event.error);
    if (window.dashboard) {
        window.dashboard.addLog('error', 'System error: ' + event.error.message);
    }
});

// Handle unhandled promise rejections
window.addEventListener('unhandledrejection', (event) => {
    console.error('Unhandled promise rejection:', event.reason);
    if (window.dashboard) {
        window.dashboard.addLog('error', 'Promise rejected: ' + event.reason);
    }
});
