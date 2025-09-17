// Global variables for forex data
let forexData = null;
let processedTableData = [];
let refreshTimer;
let currentDataSource = '28pair'; // Track current data source

// Page switching functionality
function showPage(pageId) {
    document.querySelectorAll('.page').forEach(page => {
        page.classList.remove('active');
    });
    document.getElementById(pageId).classList.add('active');
    window.scrollTo(0, 0);
}

// Switch between 10 and 28 pair views
function switchPairView(pairType) {
    // Update button states
    document.querySelectorAll('.pair-toggle-btn').forEach(btn => {
        btn.classList.remove('active');
    });
    document.getElementById(`btn-${pairType}`).classList.add('active');
    
    // Update current data source
    currentDataSource = pairType;
    
    // Load appropriate data
    loadForexData();
}

// Scroll indicator
window.addEventListener('scroll', () => {
    const scrolled = (window.scrollY / (document.documentElement.scrollHeight - window.innerHeight)) * 100;
    document.querySelector('.scroll-indicator').style.transform = `scaleX(${scrolled / 100})`;
});

// Load JSON data function
async function loadForexData() {
    try {
        showLoading(true);
        
        // Determine which JSON file to load based on current view
        const fileName = `fx_signals_${currentDataSource}.json`;
        const response = await fetch(`../data/${fileName}?` + new Date().getTime());
        
        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
        
        const data = await response.json();
        forexData = data.forexData;
        
        // Process and display the data
        processedTableData = processForexData(forexData);
        populateTable();
        generateSummary();
        showLoading(false);
        
        console.log(`Forex data loaded successfully from ${fileName}`);
        
    } catch (error) {
        console.error('Error loading forex data:', error);
        
        // Fallback to static data if JSON loading fails
        console.log('Loading fallback static data...');
    }
}

// Show/hide loading indicator
function showLoading(show) {
    const loadingIndicator = document.getElementById('loadingIndicator');
    const tableContainer = document.getElementById('tableContainer');
    const errorIndicator = document.getElementById('errorIndicator');
    
    if (show) {
        loadingIndicator.style.display = 'block';
        tableContainer.style.display = 'none';
        errorIndicator.style.display = 'none';
    } else {
        loadingIndicator.style.display = 'none';
        tableContainer.style.display = 'block';
    }
}

function processForexData(data) {
    const processed = [];
    
    for (const [pairName, pairData] of Object.entries(data)) {
        processed.push({
            pair: pairName,
            currencyStrength: pairData.Currency_Strength_Rank_all_pair,
            cciStrength: pairData.CCI_Currency_Strength_Rank_all_pair,
            bbPercent: pairData.BB_percent_ranking,
            rsiBreakout: pairData.RSI_breakout,
            overallRanking: pairData.Overall_Ranking,
            confidence: pairData.Confidence,
            signal: pairData.Signal || getEntrySignalFromRanking(pairData.Overall_Ranking),
            trigger: pairData.TRIGGER || 'OFF',
            triggerReason: pairData.TRIGGER_REASON || 'NONE'
        });
    }
    
    return processed;
}

// Generate summary section
function generateSummary() {
    const now = new Date();
    const hour = now.toLocaleTimeString('en-GB', { hour: '2-digit', hour12: false });
    const lastUpdatedTime = `${hour}:00`;

    const summaryTitle = document.getElementById('summaryTitle');
    const summaryPair = document.getElementById('summaryPair');
    const summaryEntry = document.getElementById('summaryEntry');
    const summaryTime = document.getElementById('summaryTime');
    
    // Find top confidence pair
    const topPair = processedTableData.slice().sort((a, b) => b.confidence - a.confidence)[0];

    if (topPair) {
        const entrySignal = topPair.signal;
        
        summaryTitle.textContent = `${lastUpdatedTime}の最有力分析結果（仮説）`;
        summaryPair.textContent = topPair.pair;
        summaryEntry.textContent = entrySignal === 'Buy' ? '上方向傾向' : 
                                entrySignal === 'Sell' ? '下方向傾向' : '中立傾向';
        summaryEntry.className = `summary-entry ${entrySignal === 'Buy' ? 'up' : entrySignal === 'Sell' ? 'down' : 'neutral'}`;
        summaryTime.textContent = `最終更新: ${lastUpdatedTime} | 期待度: ${topPair.confidence}%`;
    }
}

function populateTable() {
    const tbody = document.getElementById('dataTable');
    tbody.innerHTML = ''; // Clear existing data
    
    const top3Confidence = getTop3ConfidenceWithMedals();
    const top3ConfidenceValues = Object.keys(top3Confidence).map(k => parseInt(k));
    
    // Sort by confidence descending
    // Sort by signal priority first (Buy/Sell before Hold), then by confidence descending, then by signal type
    const sortedData = processedTableData.slice().sort((a, b) => {
        // Define signal priority (lower number = higher priority)
        const getSignalPriority = (signal) => {
            if (signal === 'Buy' || signal === 'Sell') return 1;  // 上方向傾向 and 下方向傾向
            return 2;  // 中立傾向 (Hold/Stay)
        };
        
        // Define signal type priority for tie-breaking (when confidence is same)
        const getSignalTypePriority = (signal) => {
            if (signal === 'Sell') return 1;  // 下方向傾向 first
            if (signal === 'Buy') return 2;   // 上方向傾向 second
            return 3;  // 中立傾向 last
        };
        
        const priorityA = getSignalPriority(a.signal);
        const priorityB = getSignalPriority(b.signal);
        
        // First sort by signal priority (Buy/Sell vs Hold)
        if (priorityA !== priorityB) {
            return priorityA - priorityB;
        }
        
        // If same priority, sort by confidence descending
        if (a.confidence !== b.confidence) {
            return b.confidence - a.confidence;
        }
        
        // If same confidence, sort by signal type (Sell before Buy)
        return getSignalTypePriority(a.signal) - getSignalTypePriority(b.signal);
    });

    sortedData.forEach(row => {
        const tr = document.createElement('tr');
        const entrySignal = getDirectionFromSignal(row.signal);
        const isTop3 = top3ConfidenceValues.includes(row.confidence);
        
        // Only show medal and highlighting if signal is NOT "中立傾向" (Stay)
        const isStaySignal = entrySignal === '中立傾向';
        const shouldShowMedal = (isTop3 && !isStaySignal);
        const medal = shouldShowMedal ? (top3Confidence[row.confidence.toString()] || '') : '';
        
        // Determine entry class based on signal type
        let entryClass = 'entry-normal';
        if (entrySignal === '上方向傾向') {
            entryClass = 'entry-buy';
        } else if (entrySignal === '下方向傾向') {
            entryClass = 'entry-sell';
        } else if (entrySignal === '中立傾向') {
            entryClass = 'entry-stay';
        }
        
        // Confidence styling: normal for Stay signals, highlighted for Buy/Sell
        const confidenceClass = (isTop3 && !isStaySignal) ? 'highlight-top3' : '';
        
        tr.innerHTML = `
            <td class="pair-name">${row.pair}</td>
            <td class="${isExtremeRSI(row.rsiBreakout) ? 'highlight-rsi-extreme' : ''}">${row.rsiBreakout}</td>
            <td class="${isExtremeRanking(row.currencyStrength) ? 'highlight-extreme-ranking' : ''}">${row.currencyStrength}</td>
            <td class="${isExtremeRanking(row.cciStrength) ? 'highlight-extreme-ranking' : ''}">${row.cciStrength}</td>
            <td class="${isExtremeRanking(row.bbPercent) ? 'highlight-extreme-ranking' : ''}">${row.bbPercent}</td>
            <td class="${isExtremeRanking(row.overallRanking) ? 'highlight-extreme-ranking' : ''}">${row.overallRanking}</td>
            <td class="${confidenceClass}">${medal}${row.confidence}%</td>
            <td><span class="${entryClass}">${entrySignal}</span></td>
            <td><span class="${getTriggerClass(row.trigger)}">${formatTriggerDisplay(row.trigger, row.triggerReason)}</span></td>
        `;
        tbody.appendChild(tr);
    });
}

// Add this helper function for trigger styling
function getTriggerClass(trigger) {
    if (trigger === 'ON') return 'trigger-on';
    return 'trigger-off';
}

function getTriggerReasonText(reasonCode) {
    const reasonMap = {
        'T_1': 'EMA戻り',
        'T_2': 'RSI極値', 
        'T_3': 'RSI戻り',
        'NONE': 'なし',
        'None': 'なし'
    };
    return reasonMap[reasonCode] || reasonCode;
}

function formatTriggerDisplay(trigger, reasonCode) {
    if (trigger === 'OFF') {
        return 'OFF';
    } else if (trigger === 'ON') {
        return `ON | ${getTriggerReasonText(reasonCode)}`;
    }
    return trigger;
}

// Convert Buy/Sell signal to Japanese direction
function getDirectionFromSignal(signal) {
    if (signal === 'Buy') return '上方向傾向';
    if (signal === 'Sell') return '下方向傾向';
    return '中立傾向';
}

// Get entry signal from ranking (fallback)
function getEntrySignalFromRanking(ranking) {
    const parts = ranking.split('/');
    const leftNumber = parseInt(parts[0]);
    const rightNumber = parseInt(parts[1]);
    if (leftNumber > rightNumber) return 'Buy';
    if (leftNumber < rightNumber) return 'Sell';
    return 'Hold';
}

// Check if ranking is extreme based on current data source
function isExtremeRanking(value) {
    if (currentDataSource === '28pair') {
        return value === '1/8' || value === '8/1';
    } else if (currentDataSource === '10pair') {
        return value === '1/5' || value === '5/1';
    }
    return false;
}

// Check if RSI is extreme (>70 or <30)
function isExtremeRSI(value) {
    return value >= 70 || value <= 30;
}

// Get top 3 confidence values with medals
function getTop3ConfidenceWithMedals() {
    const confidenceValues = processedTableData
        .map(item => item.confidence)
        .sort((a, b) => b - a)
        .slice(0, 3);
    
    const medals = ['🥇', '🥈', '🥉'];
    const result = {};
    
    confidenceValues.forEach((confidence, index) => {
        result[confidence.toString()] = medals[index] || '';
    });
    
    return result;
}

// Refresh data function
function refreshData() {
    console.log('Refreshing forex data...');
    loadForexData();
}

// Auto-refresh at specific times
function startAutoRefreshAt05(runNow = false) {
    if (runNow) refreshData();

    function scheduleNext() {
        const now = new Date();
        const next = new Date(now);

        // Set to next :05 mark
        next.setHours(now.getMinutes() < 5 ? now.getHours() : now.getHours() + 1);
        next.setMinutes(5, 0, 0);

        const delay = next - now;

        refreshTimer = setTimeout(() => {
            refreshData();
            scheduleNext();
        }, delay);
    }

    scheduleNext();
    console.log('Auto-refresh scheduled at every HH:05');
}

// File update checker
async function checkForUpdates() {
    try {
        const fileName = `fx_signals_${currentDataSource}.json`;
        const response = await fetch(`../data/${fileName}?` + new Date().getTime());
        if (response.ok) {
            const data = await response.json();
            const newDataString = JSON.stringify(data);
            const currentDataString = JSON.stringify({forexData});
            
            if (newDataString !== currentDataString) {
                console.log(`${fileName} updated, refreshing data...`);
                loadForexData();
            }
        }
    } catch (error) {
        console.log('Update check failed:', error.message);
    }
}

function startUpdateChecker() {
    setInterval(checkForUpdates, 300000); // 5 minutes
    console.log('Update checker started (every 5 minutes)');
}

// Helper function to extract date and time from image filename
function getImageTitle(imageSrc) {
    try {
        // Extract filename from path: images/[2025_08_28][0000].png
        const filename = imageSrc.split('/').pop();
        const match = filename.match(/\[(\d{4})_(\d{2})_(\d{2})\]\[(\d{4})\]/);
        
        if (match) {
            const [, year, month, day, time] = match;
            
            // Convert month and day to Japanese format
            const monthDay = `${parseInt(month)}月${parseInt(day)}日`;
            
            // Convert time to hour format
            const hour = parseInt(time.substring(0, 2));
            const timeStr = `${hour}:00`;
            
            return `${monthDay}, ${timeStr} のエントリーしてから240時間分のチャート画像`;
        }
    } catch (error) {
        console.log('Could not parse image filename:', imageSrc);
    }
    
    // Fallback title if parsing fails
    return 'チャート画像';
}

// Alert box style modal functionality for chart images
function showModal(imageSrc) {
    // Remove existing modal if present
    const existingModal = document.getElementById('alertModal');
    if (existingModal) {
        existingModal.remove();
    }
    
    // Create modal container
    const modal = document.createElement('div');
    modal.id = 'alertModal';
    modal.style.cssText = `
        position: fixed;
        top: 0;
        left: 0;
        width: 100%;
        height: 100%;
        background-color: rgba(0, 0, 0, 0.8);
        z-index: 10000;
        display: flex;
        justify-content: center;
        align-items: center;
        animation: fadeIn 0.3s ease;
    `;
    
    // Create alert box container
    const alertBox = document.createElement('div');
    alertBox.style.cssText = `
        background: white;
        border-radius: 12px;
        box-shadow: 0 20px 60px rgba(0, 0, 0, 0.4);
        max-width: 90vw;
        max-height: 90vh;
        position: relative;
        animation: slideIn 0.3s ease;
        overflow: hidden;
    `;
    
    // Create header with close button
    const header = document.createElement('div');
    header.style.cssText = `
        background: #f8f9fa;
        padding: 15px 20px;
        border-bottom: 1px solid #e9ecef;
        display: flex;
        justify-content: space-between;
        align-items: center;
    `;
    
    const title = document.createElement('h3');
    title.textContent = getImageTitle(imageSrc);
    title.style.cssText = `
        margin: 0;
        font-size: 1.1rem;
        color: #333;
        font-weight: 600;
    `;
    
    const closeButton = document.createElement('button');
    closeButton.innerHTML = '×';
    closeButton.style.cssText = `
        background: none;
        border: none;
        font-size: 24px;
        color: #666;
        cursor: pointer;
        padding: 0;
        width: 30px;
        height: 30px;
        display: flex;
        align-items: center;
        justify-content: center;
        border-radius: 50%;
        transition: all 0.2s ease;
    `;
    
    closeButton.onmouseover = () => {
        closeButton.style.backgroundColor = '#e9ecef';
        closeButton.style.color = '#000';
    };
    
    closeButton.onmouseout = () => {
        closeButton.style.backgroundColor = 'transparent';
        closeButton.style.color = '#666';
    };
    
    closeButton.onclick = closeModal;
    
    header.appendChild(title);
    header.appendChild(closeButton);
    
    // Create image container
    const imageContainer = document.createElement('div');
    imageContainer.style.cssText = `
        padding: 20px;
        text-align: center;
        background: white;
    `;
    
    // Create image element
    const img = document.createElement('img');
    img.src = imageSrc;
    img.alt = 'チャート画像';
    img.style.cssText = `
        max-width: 100%;
        max-height: 70vh;
        border-radius: 8px;
        box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
    `;
    
    // Handle image load error
    img.onerror = () => {
        img.style.display = 'none';
        const errorMsg = document.createElement('div');
        errorMsg.textContent = '画像を読み込めませんでした';
        errorMsg.style.cssText = `
            color: #dc3545;
            padding: 40px;
            font-size: 1.1rem;
        `;
        imageContainer.appendChild(errorMsg);
    };
    
    imageContainer.appendChild(img);
    
    // Assemble the alert box
    alertBox.appendChild(header);
    alertBox.appendChild(imageContainer);
    modal.appendChild(alertBox);
    
    // Add to document
    document.body.appendChild(modal);
    
    // Close modal when clicking outside the alert box
    modal.onclick = function(event) {
        if (event.target === modal) {
            closeModal();
        }
    };
    
    // Add CSS keyframes for animations
    if (!document.getElementById('modalAnimations')) {
        const style = document.createElement('style');
        style.id = 'modalAnimations';
        style.textContent = `
            @keyframes fadeIn {
                from { opacity: 0; }
                to { opacity: 1; }
            }
            @keyframes slideIn {
                from { 
                    opacity: 0;
                    transform: translateY(-20px) scale(0.95);
                }
                to { 
                    opacity: 1;
                    transform: translateY(0) scale(1);
                }
            }
        `;
        document.head.appendChild(style);
    }
}

function closeModal() {
    const modal = document.getElementById('alertModal');
    if (modal) {
        modal.style.animation = 'fadeOut 0.2s ease';
        setTimeout(() => {
            modal.remove();
        }, 200);
    }
}

// Close modal with Escape key
document.addEventListener('keydown', function(event) {
    if (event.key === 'Escape') {
        closeModal();
    }
});

// Add fadeOut animation
const existingStyle = document.getElementById('modalAnimations');
if (existingStyle) {
    existingStyle.textContent += `
        @keyframes fadeOut {
            from { opacity: 1; }
            to { opacity: 0; }
        }
    `;
}

// Function to detect Win/Lose from image filename and apply frame styling
function getFrameClass(imageSrc) {
    if (imageSrc.includes('[Win]')) {
        return 'win-frame';
    } else if (imageSrc.includes('[Lose]')) {
        return 'lose-frame';
    }
    return '';  // No special frame for regular images
}

// Function to apply Win/Lose frames to all chart thumbnails
function applyWinLoseFrames() {
    const thumbnails = document.querySelectorAll('.chart-thumbnail');
    thumbnails.forEach(img => {
        const frameClass = getFrameClass(img.src);
        if (frameClass) {
            img.classList.add(frameClass);
        }
    });
}

// Date array for verification results table - edit this array directly
const verificationDates = [
    '2025_08_28',
    '2025_08_29', 
    '2025_09_01',
    '2025_09_02',
    '2025_09_03',
    '2025_09_04',
    '2025_09_05',
    '2025_09_08',  // Change this to '2025_09_06' if needed
    '2025_09_09',
    '2025_09_10'
];

// Time slots for the verification table (24 hours)
const timeSlots = [
    '0:00', '1:00', '2:00', '3:00', '4:00', '5:00',
    '6:00', '7:00', '8:00', '9:00', '10:00', '11:00',
    '12:00', '13:00', '14:00', '15:00', '16:00', '17:00',
    '18:00', '19:00', '20:00', '21:00', '22:00', '23:00'
];

// Function to format date for display (convert 2025_08_28 to 8月28日)
function formatDateForDisplay(dateString) {
    const [year, month, day] = dateString.split('_');
    return `${parseInt(month)}月${parseInt(day)}日`;
}

// Function to format time for filename (convert "0:00" to "0000")
function formatTimeForFilename(timeString) {
    const hour = timeString.split(':')[0];
    return hour.padStart(2, '0') + '00';
}

// Function to generate table header
function generateTableHeader() {
    let headerHTML = '<tr><th style="text-align: center;">エントリー</th>';
    
    verificationDates.forEach(date => {
        const displayDate = formatDateForDisplay(date);
        headerHTML += `<th style="text-align: center;">${displayDate}</th>`;
    });
    
    headerHTML += '</tr>';
    return headerHTML;
}

// Function to generate table body
function generateTableBody() {
    let bodyHTML = '';
    
    timeSlots.forEach(time => {
        bodyHTML += `<tr><td>${time}</td>`;
        
        verificationDates.forEach(date => {
            const timeFormatted = formatTimeForFilename(time);
            const imagePath = `../images/[${date}][${timeFormatted}].png`;
            
            bodyHTML += `
                <td onclick="showModal('${imagePath}')">
                    <img src="${imagePath}" alt="チャート画像" class="chart-thumbnail">
                </td>
            `;
        });
        
        bodyHTML += '</tr>';
    });
    
    return bodyHTML;
}

// Function to generate and update verification results table
function generateVerificationTable() {
    const tableContainer = document.querySelector('#results .table-container table');
    
    if (tableContainer) {
        const thead = tableContainer.querySelector('thead');
        const tbody = tableContainer.querySelector('tbody');
        
        if (thead) {
            thead.innerHTML = generateTableHeader();
        }
        
        if (tbody) {
            tbody.innerHTML = generateTableBody();
            
            // Apply Win/Lose frames after generating the table
            setTimeout(() => {
                applyWinLoseFrames();
            }, 100);
        }
    }
}

// Initialize everything when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    console.log('Initializing FX Analysis Tool...');
    
    // Load default data (28pair)
    loadForexData();
    startAutoRefreshAt05();
    startUpdateChecker();
    
    // Apply frames after page loads
    setTimeout(applyWinLoseFrames, 100);
    
    // Initialize the verification table
    setTimeout(() => {
        generateVerificationTable();
    }, 500);
});

// Export functions for external use
window.ForexDataManager = {
    refresh: refreshData,
    getData: () => processedTableData,
    getRawData: () => forexData,
    loadFromFile: loadForexData,
    switchView: switchPairView,
    getCurrentView: () => currentDataSource
};