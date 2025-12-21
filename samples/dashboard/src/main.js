// Dashboard - Intermediate Sample Application for Zylix v0.6.0
//
// Demonstrates:
// - Real-time data visualization
// - Charts and graphs
// - Data tables
// - Export functionality
// - Responsive layout

import { ZylixApp, Component, State } from 'zylix';

// ============================================================================
// Utilities
// ============================================================================

/**
 * Escapes HTML special characters to prevent XSS attacks
 */
function escapeHtml(str) {
    if (str == null) return '';
    return String(str)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#039;');
}

/**
 * Escapes a value for use in HTML attributes
 */
function escapeAttr(str) {
    if (str == null) return '';
    return String(str)
        .replace(/&/g, '&amp;')
        .replace(/"/g, '&quot;');
}

/**
 * Escapes a value for CSV export (RFC 4180 compliant)
 */
function escapeCSV(val) {
    const str = String(val);
    if (str.includes(',') || str.includes('"') || str.includes('\n') || str.includes('\r')) {
        return `"${str.replace(/"/g, '""')}"`;
    }
    return str;
}

// ============================================================================
// Mock Data Generator
// ============================================================================

function generateMetrics() {
    return {
        revenue: Math.random() * 100000 + 50000,
        orders: Math.floor(Math.random() * 500) + 100,
        customers: Math.floor(Math.random() * 200) + 50,
        conversion: Math.random() * 5 + 2
    };
}

function generateChartData(days = 30) {
    const data = [];
    const now = new Date();

    // Fixed: Generate exactly 'days' data points (was off-by-one)
    for (let i = days - 1; i >= 0; i--) {
        const date = new Date(now);
        date.setDate(date.getDate() - i);

        data.push({
            date: date.toISOString().split('T')[0],
            revenue: Math.random() * 5000 + 2000,
            orders: Math.floor(Math.random() * 100) + 20,
            visitors: Math.floor(Math.random() * 1000) + 200
        });
    }

    return data;
}

function generateTableData(count = 50) {
    const statuses = ['completed', 'pending', 'processing', 'shipped'];
    const products = ['Widget A', 'Gadget B', 'Tool C', 'Device D', 'Item E'];

    return Array.from({ length: count }, (_, i) => ({
        id: `ORD-${String(i + 1).padStart(4, '0')}`,
        customer: `Customer ${i + 1}`,
        product: products[Math.floor(Math.random() * products.length)],
        amount: Math.random() * 500 + 50,
        status: statuses[Math.floor(Math.random() * statuses.length)],
        date: new Date(Date.now() - Math.random() * 30 * 24 * 60 * 60 * 1000).toISOString()
    }));
}

// ============================================================================
// State Management
// ============================================================================

class DashboardStore extends State {
    constructor() {
        super({
            metrics: generateMetrics(),
            chartData: generateChartData(),
            tableData: generateTableData(),
            selectedPeriod: '30d',
            isLoading: false,
            // Table state
            sortColumn: 'date',
            sortDirection: 'desc',
            currentPage: 1,
            pageSize: 10,
            tableFilter: ''
        });

        // Store interval as instance property, not in state (prevents unnecessary re-renders)
        this.refreshInterval = null;
    }

    setPeriod(period) {
        const days = period === '7d' ? 7 : period === '30d' ? 30 : 90;
        this.setState({
            selectedPeriod: period,
            chartData: generateChartData(days)
        });
    }

    refreshData() {
        this.setState({
            metrics: generateMetrics(),
            tableData: generateTableData()
        });
    }

    startAutoRefresh(interval = 30000) {
        this.stopAutoRefresh();
        this.refreshInterval = setInterval(() => this.refreshData(), interval);
    }

    stopAutoRefresh() {
        if (this.refreshInterval) {
            clearInterval(this.refreshInterval);
            this.refreshInterval = null;
        }
    }

    // Table operations
    setTableFilter(filter) {
        this.setState({ tableFilter: filter, currentPage: 1 });
    }

    setSortColumn(column) {
        const { sortColumn, sortDirection } = this.state;
        this.setState({
            sortColumn: column,
            sortDirection: sortColumn === column && sortDirection === 'asc' ? 'desc' : 'asc'
        });
    }

    setPage(page) {
        this.setState({ currentPage: page });
    }

    getSortedData() {
        const { tableData, sortColumn, sortDirection, tableFilter } = this.state;

        let filtered = tableData;

        if (tableFilter) {
            const lowerFilter = tableFilter.toLowerCase();
            filtered = tableData.filter(row =>
                row.id.toLowerCase().includes(lowerFilter) ||
                row.customer.toLowerCase().includes(lowerFilter) ||
                row.product.toLowerCase().includes(lowerFilter)
            );
        }

        return [...filtered].sort((a, b) => {
            const aVal = a[sortColumn];
            const bVal = b[sortColumn];
            const direction = sortDirection === 'asc' ? 1 : -1;

            if (typeof aVal === 'string') {
                return aVal.localeCompare(bVal) * direction;
            }
            return (aVal - bVal) * direction;
        });
    }

    getPagedData() {
        const { currentPage, pageSize } = this.state;
        const sorted = this.getSortedData();
        const start = (currentPage - 1) * pageSize;
        return sorted.slice(start, start + pageSize);
    }

    getTotalPages() {
        const { pageSize } = this.state;
        return Math.ceil(this.getSortedData().length / pageSize);
    }

    exportToCSV() {
        const headers = ['ID', 'Customer', 'Product', 'Amount', 'Status', 'Date'];
        const rows = this.state.tableData.map(row => [
            row.id,
            row.customer,
            row.product,
            row.amount.toFixed(2),
            row.status,
            new Date(row.date).toLocaleDateString()
        ]);

        // Proper CSV escaping
        const csv = [headers, ...rows]
            .map(row => row.map(escapeCSV).join(','))
            .join('\n');

        const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = 'dashboard-export.csv';
        a.click();
        URL.revokeObjectURL(url);
    }
}

// ============================================================================
// Components
// ============================================================================

class MetricCard extends Component {
    render() {
        const { title, value, change, icon, format } = this.props;
        const isPositive = change >= 0;
        const formattedValue = format === 'currency'
            ? `$${value.toLocaleString(undefined, { maximumFractionDigits: 0 })}`
            : format === 'percent'
                ? `${value.toFixed(1)}%`
                : value.toLocaleString();

        return `
            <div class="metric-card">
                <div class="metric-icon">${escapeHtml(icon)}</div>
                <div class="metric-content">
                    <div class="metric-value">${escapeHtml(formattedValue)}</div>
                    <div class="metric-title">${escapeHtml(title)}</div>
                    <div class="metric-change ${isPositive ? 'positive' : 'negative'}">
                        ${isPositive ? '↑' : '↓'} ${Math.abs(change).toFixed(1)}%
                    </div>
                </div>
            </div>
        `;
    }
}

class LineChart extends Component {
    render() {
        const { data, title, xKey, yKey, color } = this.props;

        // Handle empty or insufficient data
        if (!data || data.length === 0) {
            return `
                <div class="chart-container">
                    <h3 class="chart-title">${escapeHtml(title)}</h3>
                    <div class="chart-empty">No data available</div>
                </div>
            `;
        }

        // Simple SVG line chart
        const width = 600;
        const height = 200;
        const padding = 40;

        // Handle single data point
        const xScale = (i) => data.length === 1
            ? width / 2
            : padding + (i / (data.length - 1)) * (width - 2 * padding);

        const maxY = Math.max(...data.map(d => d[yKey])) || 1;
        const yScale = (v) => height - padding - (v / maxY) * (height - 2 * padding);

        const points = data.map((d, i) => `${xScale(i)},${yScale(d[yKey])}`).join(' ');

        return `
            <div class="chart-container">
                <h3 class="chart-title">${escapeHtml(title)}</h3>
                <svg viewBox="0 0 ${width} ${height}" class="line-chart">
                    <!-- Grid lines -->
                    ${[0, 0.25, 0.5, 0.75, 1].map(ratio => `
                        <line x1="${padding}" y1="${yScale(maxY * ratio)}"
                              x2="${width - padding}" y2="${yScale(maxY * ratio)}"
                              stroke="#ddd" stroke-dasharray="4" />
                    `).join('')}

                    <!-- Line -->
                    <polyline points="${points}" fill="none"
                              stroke="${escapeAttr(color)}" stroke-width="2" />

                    <!-- Data points -->
                    ${data.map((d, i) => `
                        <circle cx="${xScale(i)}" cy="${yScale(d[yKey])}"
                                r="4" fill="${escapeAttr(color)}" />
                    `).join('')}

                    <!-- X axis labels -->
                    ${data.filter((_, i) => i % Math.max(1, Math.floor(data.length / 6)) === 0).map((d, idx, arr) => {
                        const i = data.indexOf(d);
                        return `
                            <text x="${xScale(i)}" y="${height - 10}"
                                  text-anchor="middle" font-size="10">${escapeHtml(d[xKey].slice(5))}</text>
                        `;
                    }).join('')}
                </svg>
            </div>
        `;
    }
}

class BarChart extends Component {
    render() {
        const { data, title, labels, values, colors } = this.props;

        // Handle empty data
        if (!data || data.length === 0) {
            return `
                <div class="chart-container">
                    <h3 class="chart-title">${escapeHtml(title)}</h3>
                    <div class="chart-empty">No data available</div>
                </div>
            `;
        }

        const width = 400;
        const height = 200;
        const padding = 40;
        const barWidth = (width - 2 * padding) / data.length - 10;

        const maxVal = Math.max(...data.map(d => d[values])) || 1;

        return `
            <div class="chart-container">
                <h3 class="chart-title">${escapeHtml(title)}</h3>
                <svg viewBox="0 0 ${width} ${height}" class="bar-chart">
                    ${data.map((d, i) => {
                        const barHeight = (d[values] / maxVal) * (height - 2 * padding);
                        const x = padding + i * (barWidth + 10);
                        const y = height - padding - barHeight;

                        return `
                            <rect x="${x}" y="${y}" width="${barWidth}" height="${barHeight}"
                                  fill="${escapeAttr(colors[i % colors.length])}" rx="4" />
                            <text x="${x + barWidth / 2}" y="${height - 10}"
                                  text-anchor="middle" font-size="10">${escapeHtml(d[labels])}</text>
                            <text x="${x + barWidth / 2}" y="${y - 5}"
                                  text-anchor="middle" font-size="10">${d[values]}</text>
                        `;
                    }).join('')}
                </svg>
            </div>
        `;
    }
}

class DataTable extends Component {
    render() {
        const { data, currentPage, totalPages, tableFilter, sortColumn, sortDirection } = this.props;

        return `
            <div class="data-table-container">
                <div class="table-toolbar">
                    <input type="search" placeholder="Search..."
                           value="${escapeAttr(tableFilter)}"
                           data-action="table-filter"
                           class="table-search" />
                    <button class="btn btn-secondary" data-action="export">
                        📥 Export CSV
                    </button>
                </div>

                <table class="data-table">
                    <thead>
                        <tr>
                            <th data-action="sort" data-column="id">
                                Order ID ${sortColumn === 'id' ? (sortDirection === 'asc' ? '↑' : '↓') : ''}
                            </th>
                            <th data-action="sort" data-column="customer">
                                Customer ${sortColumn === 'customer' ? (sortDirection === 'asc' ? '↑' : '↓') : ''}
                            </th>
                            <th data-action="sort" data-column="product">
                                Product ${sortColumn === 'product' ? (sortDirection === 'asc' ? '↑' : '↓') : ''}
                            </th>
                            <th data-action="sort" data-column="amount">
                                Amount ${sortColumn === 'amount' ? (sortDirection === 'asc' ? '↑' : '↓') : ''}
                            </th>
                            <th data-action="sort" data-column="status">
                                Status ${sortColumn === 'status' ? (sortDirection === 'asc' ? '↑' : '↓') : ''}
                            </th>
                            <th data-action="sort" data-column="date">
                                Date ${sortColumn === 'date' ? (sortDirection === 'asc' ? '↑' : '↓') : ''}
                            </th>
                        </tr>
                    </thead>
                    <tbody>
                        ${data.map(row => `
                            <tr>
                                <td>${escapeHtml(row.id)}</td>
                                <td>${escapeHtml(row.customer)}</td>
                                <td>${escapeHtml(row.product)}</td>
                                <td>$${row.amount.toFixed(2)}</td>
                                <td>
                                    <span class="status-badge status-${escapeAttr(row.status)}">
                                        ${escapeHtml(row.status)}
                                    </span>
                                </td>
                                <td>${escapeHtml(new Date(row.date).toLocaleDateString())}</td>
                            </tr>
                        `).join('')}
                    </tbody>
                </table>

                <div class="table-pagination">
                    <button data-action="prev-page" ${currentPage === 1 ? 'disabled' : ''}>
                        Previous
                    </button>
                    <span>Page ${currentPage} of ${totalPages}</span>
                    <button data-action="next-page" ${currentPage === totalPages ? 'disabled' : ''}>
                        Next
                    </button>
                </div>
            </div>
        `;
    }
}

class Sidebar extends Component {
    render() {
        const { activePage } = this.props;

        const menuItems = [
            { id: 'overview', icon: '📊', label: 'Overview' },
            { id: 'analytics', icon: '📈', label: 'Analytics' },
            { id: 'orders', icon: '📦', label: 'Orders' },
            { id: 'customers', icon: '👥', label: 'Customers' },
            { id: 'products', icon: '🏷️', label: 'Products' },
            { id: 'settings', icon: '⚙️', label: 'Settings' }
        ];

        return `
            <aside class="sidebar">
                <div class="sidebar-header">
                    <h2>Dashboard</h2>
                </div>
                <nav class="sidebar-nav">
                    ${menuItems.map(item => `
                        <a href="#${escapeAttr(item.id)}"
                           class="nav-item ${activePage === item.id ? 'active' : ''}">
                            <span class="nav-icon">${item.icon}</span>
                            <span class="nav-label">${escapeHtml(item.label)}</span>
                        </a>
                    `).join('')}
                </nav>
            </aside>
        `;
    }
}

// ============================================================================
// App
// ============================================================================

class DashboardApp extends Component {
    constructor() {
        super();
        this.store = new DashboardStore();
        this.store.subscribe(() => this.render());
        this.store.startAutoRefresh();

        this.boundHandleClick = this.handleClick.bind(this);
        this.boundHandleInput = this.handleInput.bind(this);
        this.boundHandleChange = this.handleChange.bind(this);
    }

    mount(container) {
        this.container = container;
        this.render();
        this.attachEventListeners();
    }

    attachEventListeners() {
        if (!this.container) return;

        this.container.addEventListener('click', this.boundHandleClick);
        this.container.addEventListener('input', this.boundHandleInput);
        this.container.addEventListener('change', this.boundHandleChange);
    }

    handleClick(event) {
        const target = event.target.closest('[data-action]');
        if (!target) return;

        const action = target.dataset.action;

        switch (action) {
            case 'refresh':
                this.store.refreshData();
                break;
            case 'export':
                this.store.exportToCSV();
                break;
            case 'sort':
                this.store.setSortColumn(target.dataset.column);
                break;
            case 'prev-page':
                this.store.setPage(this.store.state.currentPage - 1);
                break;
            case 'next-page':
                this.store.setPage(this.store.state.currentPage + 1);
                break;
        }
    }

    handleInput(event) {
        const target = event.target;
        if (target.dataset.action === 'table-filter') {
            this.store.setTableFilter(target.value);
        }
    }

    handleChange(event) {
        const target = event.target;
        if (target.dataset.action === 'period-select') {
            this.store.setPeriod(target.value);
        }
    }

    render() {
        const { metrics, chartData, selectedPeriod, currentPage, tableFilter, sortColumn, sortDirection } = this.store.state;
        const pagedData = this.store.getPagedData();
        const totalPages = this.store.getTotalPages();

        const html = `
            <div class="dashboard-app">
                ${new Sidebar({ activePage: 'overview' }).render()}

                <main class="dashboard-main">
                    <header class="dashboard-header">
                        <h1>Dashboard Overview</h1>
                        <div class="header-actions">
                            <select class="period-select" data-action="period-select">
                                <option value="7d" ${selectedPeriod === '7d' ? 'selected' : ''}>Last 7 days</option>
                                <option value="30d" ${selectedPeriod === '30d' ? 'selected' : ''}>Last 30 days</option>
                                <option value="90d" ${selectedPeriod === '90d' ? 'selected' : ''}>Last 90 days</option>
                            </select>
                            <button class="btn btn-primary" data-action="refresh">
                                🔄 Refresh
                            </button>
                        </div>
                    </header>

                    <section class="metrics-grid">
                        ${new MetricCard({
                            title: 'Total Revenue',
                            value: metrics.revenue,
                            change: 12.5,
                            icon: '💰',
                            format: 'currency'
                        }).render()}
                        ${new MetricCard({
                            title: 'Orders',
                            value: metrics.orders,
                            change: 8.2,
                            icon: '📦',
                            format: 'number'
                        }).render()}
                        ${new MetricCard({
                            title: 'Customers',
                            value: metrics.customers,
                            change: -2.4,
                            icon: '👥',
                            format: 'number'
                        }).render()}
                        ${new MetricCard({
                            title: 'Conversion Rate',
                            value: metrics.conversion,
                            change: 5.1,
                            icon: '📈',
                            format: 'percent'
                        }).render()}
                    </section>

                    <section class="charts-grid">
                        ${new LineChart({
                            data: chartData,
                            title: 'Revenue Over Time',
                            xKey: 'date',
                            yKey: 'revenue',
                            color: '#4F46E5'
                        }).render()}
                        ${new LineChart({
                            data: chartData,
                            title: 'Orders Over Time',
                            xKey: 'date',
                            yKey: 'orders',
                            color: '#10B981'
                        }).render()}
                    </section>

                    <section class="table-section">
                        <h2>Recent Orders</h2>
                        ${new DataTable({
                            data: pagedData,
                            currentPage,
                            totalPages,
                            tableFilter,
                            sortColumn,
                            sortDirection
                        }).render()}
                    </section>
                </main>
            </div>
        `;

        if (this.container) {
            this.container.innerHTML = html;
        }

        return html;
    }
}

// ============================================================================
// Initialize
// ============================================================================

const app = new ZylixApp({
    root: '#app',
    component: DashboardApp
});

app.mount();

export { DashboardApp, DashboardStore, escapeHtml, escapeAttr, escapeCSV };
