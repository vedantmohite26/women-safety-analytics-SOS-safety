tbody.innerHTML = `
            <tr>
                <td colspan="6" style="text-align: center; padding: 40px; color: #9CA3AF;">
                    No users found
                </td>
            </tr>
        `;
return;
    }

tbody.innerHTML = usersData.map(user => {
    const initial = (user.displayName || user.email || 'U')[0].toUpperCase();
    const contactNumber = user.contactPhoneNumber || 'Not set';
    const authPhone = user.phoneNumber || 'Not set';
    const isVerified = user.phoneVerified;
    const lastSignIn = user.lastSignIn ? formatTimestamp(user.lastSignIn) : 'Never';

    return `
            <tr>
                <td>
                    <div class="user-cell">
                        <div class="avatar-sm">${initial}</div>
                        <span>${user.displayName || 'Unknown'}</span>
                    </div>
                </td>
                <td>${user.email || 'N/A'}</td>
                <td><strong>${contactNumber}</strong></td>
                <td>${authPhone}</td>
                <td>
                    <span class="verify-badge ${isVerified ? 'verified' : 'unverified'}">
                        ${isVerified ? '✓ Verified' : '✗ Unverified'}
                    </span>
                </td>
                <td>${lastSignIn}</td>
            </tr>
        `;
}).join('');
}

// Render SOS alerts table
function renderSOSAlertsTable() {
    const tbody = document.getElementById('sos-alerts-body');

    if (sosAlertsData.length === 0) {
        tbody.innerHTML = `
            <tr>
                <td colspan="4" style="text-align: center; padding: 40px; color: #9CA3AF;">
                    No SOS alerts found
                </td>
            </tr>
        `;
        return;
    }

    // Get recent alerts (up to 10)
    const recentAlerts = sosAlertsData.slice(0, 10);

    tbody.innerHTML = recentAlerts.map(alert => {
        // Try to get user info
        const user = usersData.find(u => u.id === alert.userId);
        const userName = user?.displayName || 'Unknown User';
        const initial = (userName)[0].toUpperCase();

        // Format location
        const location = alert.location
            ? `${alert.location.latitude.toFixed(4)}, ${alert.location.longitude.toFixed(4)}`
            : 'Unknown';

        // Format time
        const time = alert.timestamp ? formatTimestamp(alert.timestamp) : 'Unknown';

        // Status
        const status = alert.status || 'active';
        const statusClass = status === 'resolved' ? 'status-resolved' : 'status-active';

        return `
            <tr>
                <td>
                    <div class="user-cell">
                        <div class="avatar-sm">${initial}</div>
                        <span>${userName}</span>
                    </div>
                </td>
                <td>${location}</td>
                <td>${time}</td>
                <td><span class="status-badge ${statusClass}">${status.charAt(0).toUpperCase() + status.slice(1)}</span></td>
            </tr>
        `;
    }).join('');
}

// Format Firestore timestamp
function formatTimestamp(timestamp) {
    if (!timestamp) return 'Unknown';

    let date;
    if (timestamp.toDate) {
        date = timestamp.toDate();
    } else if (timestamp.seconds) {
        date = new Date(timestamp.seconds * 1000);
    } else {
        date = new Date(timestamp);
    }

    const now = new Date();
    const diff = now - date;

    // Less than 1 minute
    if (diff < 60000) {
        return 'Just now';
    }
    // Less than 1 hour
    if (diff < 3600000) {
        const mins = Math.floor(diff / 60000);
        return `${mins} min${mins !== 1 ? 's' : ''} ago`;
    }
    // Less than 1 day
    if (diff < 86400000) {
        const hours = Math.floor(diff / 3600000);
        return `${hours} hour${hours !== 1 ? 's' : ''} ago`;
    }
    // Less than 7 days
    if (diff < 604800000) {
        const days = Math.floor(diff / 86400000);
        return `${days} day${days !== 1 ? 's' : ''} ago`;
    }

    // Format as date
    return date.toLocaleDateString('en-IN', {
        year: 'numeric',
        month: 'short',
        day: 'numeric',
        hour: '2-digit',
        minute: '2-digit'
    });
}

// Initialize activity chart
function initializeActivityChart() {
    const canvas = document.getElementById('activityChart');
    if (!canvas) return;

    const ctx = canvas.getContext('2d');
    const width = canvas.offsetWidth;
    const height = 300;
    canvas.width = width;
    canvas.height = height;

    // Initial draw with placeholder
    drawChart(ctx, width, height, [0, 0, 0, 0, 0, 0, 0]);
}

// Update activity chart with real data
function updateActivityChart() {
    const canvas = document.getElementById('activityChart');
    if (!canvas) return;

    const ctx = canvas.getContext('2d');
    const width = canvas.offsetWidth;
    const height = 300;

    // Group alerts by day for last 7 days
    const data = getLast7DaysData();
    drawChart(ctx, width, height, data);
}

// Get data for last 7 days
function getLast7DaysData() {
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const counts = [0, 0, 0, 0, 0, 0, 0];

    sosAlertsData.forEach(alert => {
        if (!alert.timestamp) return;

        let alertDate;
        if (alert.timestamp.toDate) {
            alertDate = alert.timestamp.toDate();
        } else if (alert.timestamp.seconds) {
            alertDate = new Date(alert.timestamp.seconds * 1000);
        } else {
            alertDate = new Date(alert.timestamp);
        }

        alertDate.setHours(0, 0, 0, 0);
        const diffDays = Math.floor((today - alertDate) / 86400000);

        if (diffDays >= 0 && diffDays < 7) {
            counts[6 - diffDays]++;
        }
    });

    return counts;
}

// Draw chart
function drawChart(ctx, width, height, data) {
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const maxValue = Math.max(...data, 1);
    const padding = 40;
    const chartWidth = width - padding * 2;
    const chartHeight = height - padding * 2;

    // Clear canvas
    ctx.clearRect(0, 0, width, height);

    // Draw gridlines
    ctx.strokeStyle = '#E5E7EB';
    ctx.lineWidth = 1;
    for (let i = 0; i <= 5; i++) {
        const y = padding + (chartHeight / 5) * i;
        ctx.beginPath();
        ctx.moveTo(padding, y);
        ctx.lineTo(width - padding, y);
        ctx.stroke();
    }

    // Draw bars
    const barWidth = chartWidth / data.length * 0.6;
    const spacing = chartWidth / data.length;

    data.forEach((value, index) => {
        const barHeight = (value / maxValue) * chartHeight;
        const x = padding + spacing * index + spacing / 2 - barWidth / 2;
        const y = height - padding - barHeight;

        // Create gradient
        const gradient = ctx.createLinearGradient(0, y, 0, y + barHeight);
        gradient.addColorStop(0, '#E91E63');
        gradient.addColorStop(1, '#F06292');

        // Draw bar
        ctx.fillStyle = gradient;
        ctx.beginPath();
        ctx.roundRect(x, y, barWidth, barHeight, [8, 8, 0, 0]);
        ctx.fill();

        // Draw label
        ctx.fillStyle = '#6B7280';
        ctx.font = '12px Inter';
        ctx.textAlign = 'center';
        ctx.fillText(labels[index], x + barWidth / 2, height - padding + 20);

        // Draw value on top of bar if > 0
        if (value > 0) {
            ctx.fillStyle = '#111827';
            ctx.font = '600 12px Inter';
            ctx.fillText(value, x + barWidth / 2, y - 8);
        }
    });
}

// Polyfill for roundRect
if (!CanvasRenderingContext2D.prototype.roundRect) {
    CanvasRenderingContext2D.prototype.roundRect = function (x, y, w, h, radii) {
        if (!radii) radii = 0;
        const r = Array.isArray(radii) ? radii : [radii, radii, radii, radii];
        this.beginPath();
        this.moveTo(x + r[0], y);
        this.lineTo(x + w - r[1], y);
        this.quadraticCurveTo(x + w, y, x + w, y + r[1]);
        this.lineTo(x + w, y + h - r[2]);
        this.quadraticCurveTo(x + w, y + h, x + w - r[2], y + h);
        this.lineTo(x + r[3], y + h);
        this.quadraticCurveTo(x, y + h, x, y + h - r[3]);
        this.lineTo(x, y + r[0]);
        this.quadraticCurveTo(x, y, x + r[0], y);
        this.closePath();
        return this;
    };
}

// Search functionality
function setupSearchFilter() {
    const searchInput = document.getElementById('user-search');
    if (searchInput) {
        searchInput.addEventListener('input', function (e) {
            const searchTerm = e.target.value.toLowerCase();
            const rows = document.querySelectorAll('#users-body tr');

            rows.forEach(row => {
                const text = row.textContent.toLowerCase();
                if (text.includes(searchTerm)) {
                    row.style.display = '';
                } else {
                    row.style.display = 'none';
                }
            });
        });
    }
}

// Refresh data manually
function refreshData() {
    showNotification('Refreshing data...', 'info');
    // Firebase listeners will automatically update
}

// Show notification
function showNotification(message, type = 'info') {
    const notification = document.createElement('div');
    notification.className = `notification notification-${type}`;
    notification.textContent = message;

    notification.style.cssText = `
        position: fixed;
        top: 24px;
        right: 24px;
        padding: 16px 24px;
        background: ${type === 'success' ? '#10B981' : type === 'error' ? '#EF4444' : '#3B82F6'};
        color: white;
        border-radius: 12px;
        box-shadow: 0 8px 24px rgba(0, 0, 0, 0.15);
        font-weight: 600;
        z-index: 9999;
        animation: slideIn 0.3s ease-out;
    `;

    document.body.appendChild(notification);

    setTimeout(() => {
        notification.style.animation = 'slideOut 0.3s ease-out';
        setTimeout(() => notification.remove(), 300);
    }, 3000);
}

// Show error
function showError(message) {
    const tbody = document.getElementById('sos-alerts-body');
    if (tbody) {
        tbody.innerHTML = `
            <tr>
                <td colspan="4" style="text-align: center; padding: 40px; color: #EF4444;">
                    <strong>Error:</strong> ${message}
                </td>
            </tr>
        `;
    }
    showNotification(message, 'error');
}

// Add animation styles
const style = document.createElement('style');
style.textContent = `
    @keyframes slideIn {
        from {
            transform: translateX(100%);
            opacity: 0;
        }
        to {
            transform: translateX(0);
            opacity: 1;
        }
    }
    
    @keyframes slideOut {
        from {
            transform: translateX(0);
            opacity: 1;
        }
        to {
            transform: translateX(100%);
            opacity: 0;
        }
    }
`;
document.head.appendChild(style);

// Handle window resize for chart
window.addEventListener('resize', function () {
    updateActivityChart();
});
