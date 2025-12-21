// Dashboard - Intermediate Sample Application for Zylix v0.6.0
//
// Demonstrates:
// - Real-time data visualization
// - Charts and graphs
// - Data tables
// - Export functionality
// - Responsive layout

import { ZylixApp, Component, State, Router, Http, Chart } from 'zylix';

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

    for (let i = days; i >= 0; i--) {
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
            refreshInterval: null
        });
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
        const refreshInterval = setInterval(() => this.refreshData(), interval);
        this.setState({ refreshInterval });
    }

    stopAutoRefresh() {
        if (this.state.refreshInterval) {
            clearInterval(this.state.refreshInterval);
            this.setState({ refreshInterval: null });
        }
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

        const csv = [headers, ...rows].map(row => row.join(',')).join('\n');
        const blob = new Blob([csv], { type: 'text/csv' });
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
                <div class="metric-icon">${icon}</div>
                <div class="metric-content">
                    <div class="metric-value">${formattedValue}</div>
                    <div class="metric-title">${title}</div>
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

        // Simple SVG line chart
        const width = 600;
        const height = 200;
        const padding = 40;

        const xScale = (i) => padding + (i / (data.length - 1)) * (width - 2 * padding);
        const maxY = Math.max(...data.map(d => d[yKey]));
        const yScale = (v) => height - padding - (v / maxY) * (height - 2 * padding);

        const points = data.map((d, i) => `${xScale(i)},${yScale(d[yKey])}`).join(' ');

        return `
            <div class="chart-container">
                <h3 class="chart-title">${title}</h3>
                <svg viewBox="0 0 ${width} ${height}" class="line-chart">
                    <!-- Grid lines -->
                    ${[0, 0.25, 0.5, 0.75, 1].map(ratio => `
                        <line x1="${padding}" y1="${yScale(maxY * ratio)}"
                              x2="${width - padding}" y2="${yScale(maxY * ratio)}"
                              stroke="#ddd" stroke-dasharray="4" />
                    `).join('')}

                    <!-- Line -->
                    <polyline points="${points}" fill="none"
                              stroke="${color}" stroke-width="2" />

                    <!-- Data points -->
                    ${data.map((d, i) => `
                        <circle cx="${xScale(i)}" cy="${yScale(d[yKey])}"
                                r="4" fill="${color}" />
                    `).join('')}

                    <!-- X axis labels -->
                    ${data.filter((_, i) => i % 5 === 0).map((d, i) => `
                        <text x="${xScale(i * 5)}" y="${height - 10}"
                              text-anchor="middle" font-size="10">${d[xKey].slice(5)}</text>
                    `).join('')}
                </svg>
            </div>
        `;
    }
}

class BarChart extends Component {
    render() {
        const { data, title, labels, values, colors } = this.props;

        const width = 400;
        const height = 200;
        const padding = 40;
        const barWidth = (width - 2 * padding) / data.length - 10;

        const maxVal = Math.max(...data.map(d => d[values]));

        return `
            <div class="chart-container">
                <h3 class="chart-title">${title}</h3>
                <svg viewBox="0 0 ${width} ${height}" class="bar-chart">
                    ${data.map((d, i) => {
                        const barHeight = (d[values] / maxVal) * (height - 2 * padding);
                        const x = padding + i * (barWidth + 10);
                        const y = height - padding - barHeight;

                        return `
                            <rect x="${x}" y="${y}" width="${barWidth}" height="${barHeight}"
                                  fill="${colors[i % colors.length]}" rx="4" />
                            <text x="${x + barWidth / 2}" y="${height - 10}"
                                  text-anchor="middle" font-size="10">${d[labels]}</text>
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
    constructor(props) {
        super(props);
        this.state = {
            sortColumn: 'date',
            sortDirection: 'desc',
            currentPage: 1,
            pageSize: 10,
            filter: ''
        };
    }

    getSortedData() {
        const { data } = this.props;
        const { sortColumn, sortDirection, filter } = this.state;

        let filtered = data;

        if (filter) {
            const lowerFilter = filter.toLowerCase();
            filtered = data.filter(row =>
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

    render() {
        const { onExport } = this.props;
        const { currentPage, pageSize, filter } = this.state;
        const sorted = this.getSortedData();
        const paged = this.getPagedData();
        const totalPages = Math.ceil(sorted.length / pageSize);

        return `
            <div class="data-table-container">
                <div class="table-toolbar">
                    <input type="search" placeholder="Search..."
                           value="${filter}" oninput="handleTableFilter(event)"
                           class="table-search" />
                    <button class="btn btn-secondary" onclick="exportData()">
                        📥 Export CSV
                    </button>
                </div>

                <table class="data-table">
                    <thead>
                        <tr>
                            <th onclick="sortTable('id')">Order ID</th>
                            <th onclick="sortTable('customer')">Customer</th>
                            <th onclick="sortTable('product')">Product</th>
                            <th onclick="sortTable('amount')">Amount</th>
                            <th onclick="sortTable('status')">Status</th>
                            <th onclick="sortTable('date')">Date</th>
                        </tr>
                    </thead>
                    <tbody>
                        ${paged.map(row => `
                            <tr>
                                <td>${row.id}</td>
                                <td>${row.customer}</td>
                                <td>${row.product}</td>
                                <td>$${row.amount.toFixed(2)}</td>
                                <td>
                                    <span class="status-badge status-${row.status}">
                                        ${row.status}
                                    </span>
                                </td>
                                <td>${new Date(row.date).toLocaleDateString()}</td>
                            </tr>
                        `).join('')}
                    </tbody>
                </table>

                <div class="table-pagination">
                    <button onclick="prevPage()" ${currentPage === 1 ? 'disabled' : ''}>
                        Previous
                    </button>
                    <span>Page ${currentPage} of ${totalPages}</span>
                    <button onclick="nextPage()" ${currentPage === totalPages ? 'disabled' : ''}>
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
                        <a href="#${item.id}"
                           class="nav-item ${activePage === item.id ? 'active' : ''}">
                            <span class="nav-icon">${item.icon}</span>
                            <span class="nav-label">${item.label}</span>
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
    }

    render() {
        const { metrics, chartData, tableData, selectedPeriod } = this.store.state;

        return `
            <div class="dashboard-app">
                ${new Sidebar({ activePage: 'overview' }).render()}

                <main class="dashboard-main">
                    <header class="dashboard-header">
                        <h1>Dashboard Overview</h1>
                        <div class="header-actions">
                            <select class="period-select" onchange="changePeriod(event)">
                                <option value="7d" ${selectedPeriod === '7d' ? 'selected' : ''}>Last 7 days</option>
                                <option value="30d" ${selectedPeriod === '30d' ? 'selected' : ''}>Last 30 days</option>
                                <option value="90d" ${selectedPeriod === '90d' ? 'selected' : ''}>Last 90 days</option>
                            </select>
                            <button class="btn btn-primary" onclick="refreshData()">
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
                            data: tableData,
                            onExport: () => this.store.exportToCSV()
                        }).render()}
                    </section>
                </main>
            </div>
        `;
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

export { DashboardApp, DashboardStore };
