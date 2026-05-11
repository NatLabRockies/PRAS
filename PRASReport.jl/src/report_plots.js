window.renderEventPlots = function(systemData, stepSize, energyUnit, timeUnit) {
    const durations = systemData.duration;
    const energies = systemData.energy;
    const sampleIds = systemData.sample_id;

    Plotly.newPlot("duration-histogram", [{
        x: durations,
        type: "histogram",
        xbins: { size: stepSize },
        marker: {
            color: "#b8c5d4"
        },
        hovertemplate: "Duration: %{x}<br>Count: %{y}<extra></extra>"
    }], {
        title: "System Event Duration Distribution",
        xaxis: { title: `Duration (${timeUnit})` },
        yaxis: { title: "Number of Events" },
        margin: { t: 50, l: 60, r: 20, b: 60 }
    }, { responsive: true });

    Plotly.newPlot("energy-scatter", [{
        x: durations,
        y: energies,
        customdata: sampleIds,
        mode: "markers",
        type: "scattergl",
        marker: {
            size: 8,
            opacity: 0.8,
            color: energies,
            colorscale: "Viridis",
            showscale: true,
            colorbar: {
                title: {
                    text: energyUnit,
                    side: "right",
                    font: {
                        size: 12
                    }
                },
                len: 0.85,
                thickness: 12,
                outlinewidth: 0,
                tickwidth: 0.5
            }
        },
        hovertemplate:
            "Sample %{customdata}<br>Duration: %{x}<br>Energy: %{y:.2f} " + energyUnit + "<extra></extra>"
    }], {
        title: "System Event Energy vs Duration",
        xaxis: {
            title: `Duration (${timeUnit})`,
            constrain: "domain"
        },
        yaxis: {
            title: `Energy (${energyUnit})`,
            showline: false,
            zeroline: false
        },
        margin: { t: 60, l: 80, r: 140, b: 80 }
    }, { responsive: true });
};

window.renderRegionalEventPlots = function(regionalData, stepSize, energyUnit, timeUnit) {
    const regions = [...regionalData.keys()].sort();

    const traces = [];
    const layout = {
        title: "Regional Event Duration and Energy",
        showlegend: false,
        height: Math.max(700, 300 * Math.ceil(regions.length / 4)),
        margin: { t: 70, l: 60, r: 120, b: 60 },
        annotations: []
    };

    const cols = Math.min(4, Math.max(1, regions.length));
    const facetRows = Math.ceil(regions.length / cols);
    const totalRows = facetRows * 2;

    const rowHeight = 1 / totalRows;
    const colWidth = 1 / cols;

    const allEnergies = [];
    regions.forEach(region => {
        const data = regionalData.get(region);
        allEnergies.push(...data.energy);
    });

    const cmin = Math.min(...allEnergies);
    const cmax = Math.max(...allEnergies);

    regions.forEach((region, idx) => {
        const facetRow = Math.floor(idx / cols);
        const facetCol = idx % cols;

        const x0 = facetCol * colWidth + 0.04;
        const x1 = (facetCol + 1) * colWidth - 0.03;

        const histRow = facetRow * 2;
        const scatterRow = histRow + 1;

        const yHist0 = 1 - (histRow + 1) * rowHeight + 0.04;
        const yHist1 = 1 - histRow * rowHeight - 0.04;

        const yScat0 = 1 - (scatterRow + 1) * rowHeight + 0.04;
        const yScat1 = 1 - scatterRow * rowHeight - 0.04;

        const xaxisName = idx === 0 ? "xaxis" : `xaxis${2 * idx + 1}`;
        const yaxisName = idx === 0 ? "yaxis" : `yaxis${2 * idx + 1}`;
        const xaxisName2 = `xaxis${2 * idx + 2}`;
        const yaxisName2 = `yaxis${2 * idx + 2}`;

        const xref = idx === 0 ? "x" : `x${2 * idx + 1}`;
        const yref = idx === 0 ? "y" : `y${2 * idx + 1}`;
        const xref2 = `x${2 * idx + 2}`;
        const yref2 = `y${2 * idx + 2}`;

        layout[xaxisName] = { domain: [x0, x1], anchor: yref };
        layout[yaxisName] = { domain: [yHist0, yHist1], anchor: xref, title: facetCol === 0 ? "Events" : "" };

        layout[xaxisName2] = {
            domain: [x0, x1],
            anchor: yref2,
            title: (facetRow === facetRows - 1) ? `Duration (${timeUnit})` : ""
        };
        layout[yaxisName2] = { domain: [yScat0, yScat1], anchor: xref2, title: facetCol === 0 ? `Energy (${energyUnit})` : "" };

        const data = regionalData.get(region);

        traces.push({
            x: data.duration,
            type: "histogram",
            marker: {
                color: "#b8c5d4"
            },
            xaxis: xref,
            yaxis: yref,
            xbins: { size: stepSize },
            hovertemplate: "Duration: %{x}<br>Count: %{y}<extra></extra>"
        });

        traces.push({
            x: data.duration,
            y: data.energy,
            mode: "markers",
            type: "scattergl",
            xaxis: xref2,
            yaxis: yref2,
            marker: {
                size: 7,
                opacity: 0.8,
                color: data.energy,
                colorscale: "Viridis",
                cmin: cmin,
                cmax: cmax,
                showscale: idx === regions.length - 1,
                colorbar: idx === regions.length - 1
                    ? {
                        title: {
                            text: energyUnit,
                            side: "right",
                            font: { size: 12 }
                        },
                        tickfont: { size: 12 },
                        len: 0.85,
                        thickness: 12,
                        outlinewidth: 0,
                        ticks: ""
                    }
                    : undefined
            },
            customdata: data.sample_id,
            hovertemplate:
                "Region: " + region + "<br>Sample %{customdata}<br>Duration: %{x}<br>Energy: %{y:.2f} " + energyUnit + "<extra></extra>"
        });

        layout.annotations.push({
            text: `<b><span style="text-decoration: underline;">${region}</span></b>`,
            x: (x0 + x1) / 2,
            y: yHist1 + 0.001,
            xref: "paper",
            yref: "paper",
            xanchor: "center",
            yanchor: "bottom",
            align: "center",
            showarrow: false,
            font: {
                size: 14
            }
        });
    });

    Plotly.newPlot("regional-events-faceted-plot", traces, layout, { responsive: true });
};

function wrapPlotTitle(text, maxChars = 18) {
    const words = String(text).split(/\s+/);
    const lines = [];
    let line = "";

    words.forEach(word => {
        const candidate = line ? `${line} ${word}` : word;
        if (candidate.length > maxChars && line) {
            lines.push(line);
            line = word;
        } else {
            line = candidate;
        }
    });

    if (line) lines.push(line);

    return lines.join("<br>");
}

window.renderRegionalShortfallHeatmaps = function(rows, energyUnit) {
    const container = document.getElementById("regional-shortfall-heatmaps");
    container.innerHTML = "";

    const byRegion = new Map();

    rows.forEach(row => {
        const region = row.region_name || "Unknown";
        if (!byRegion.has(region)) {
            byRegion.set(region, []);
        }
        byRegion.get(region).push(row);
    });

    [...byRegion.keys()].sort().forEach((region, idx) => {
        const div = document.createElement("div");
        const plotId = `regional-shortfall-heatmap-${idx}`;
        div.id = plotId;
        div.className = "regional-heatmap";
        container.appendChild(div);

        // const z = makeMonthHourMatrix(byRegion.get(region));
        const z = makeMonthHourMatrix(byRegion.get(region), "mean_shortfall");

        Plotly.newPlot(plotId, [{
            z: z,
            x: Array.from({ length: 24 }, (_, i) => i),
            y: Array.from({ length: 12 }, (_, i) => i + 1),
            type: "heatmap",
            xgap: 1,
            ygap: 1,
            colorscale: [
                [0, "#ffffff"],
                [0.5, "#fdae6b"],
                [1, "#d7301f"]
            ],
            showscale: idx === byRegion.size - 1,
            colorbar: idx === byRegion.size - 1
                ? {
                    title: {
                        text: `Mean Shortfall (${energyUnit})`,
                        side: "right",
                        font: {size: 11}
                    },
                    tickfont: {size: 11},
                    len: 0.85,
                    x: 1.08,
                    thickness: 12,
                    outlinewidth: 0,
                    ticks: ""
                }
                : undefined,
            hovertemplate:
                "Region: " + region +
                "<br>Month: %{y}<br>Hour: %{x}<br>Mean Shortfall: %{z:.3f} " +
                energyUnit +
                "<extra></extra>"
        }], {
            title: {
                text: `<b><u>${wrapPlotTitle(region, 18)}</u></b>`,
                font: { size: 12 }
            },
            xaxis: {
                title: {text: "Hour", font: {size: 11}},
                tickfont: {size: 11},
                showline: false,
                zeroline: false
            },
            yaxis: {
                title: {text: "Month", font: {size: 11}},
                tickfont: {size: 11},
                autorange: "reversed",
                showline: false,
                zeroline: false
            },
            plot_bgcolor: "#f5f5f5",
            paper_bgcolor: "white",
            margin: { t: 32, l: 32, r: 10, b: 32 }
        }, { responsive: true });
    });
};

window.renderSystemShortfallTimeseries = function(rows, energyUnit) {
    Plotly.newPlot("system-shortfall-timeseries", [{
        x: rows.map(r => r.timestamp),
        y: rows.map(r => Number(r.mean_shortfall || 0)),
        type: "scatter",
        mode: "lines",
        hovertemplate:
            "Time: %{x}<br>Mean Shortfall: %{y:.3f} " + energyUnit + "<extra></extra>"
    }], {
        xaxis: {
            title: "",
            showticklabels: false,
            ticks: "",
            showline: false,
            zeroline: false
        },
        yaxis: {
            title: `Mean Shortfall (${energyUnit})`,
            showline: false,
            zeroline: false
        },
        margin: { t: 20, l: 70, r: 30, b: 60 }
    }, { responsive: true });
};

function makeMonthHourMatrix(rows, valueName) {
    const z = Array.from({ length: 12 }, () => Array(24).fill(0));

    rows.forEach(row => {
        const month = Number(row.month);
        const hour = Number(row.hour);

        if (month >= 1 && month <= 12 && hour >= 0 && hour <= 23) {
            z[month - 1][hour] = Number(row[valueName] || 0);
        }
    });

    return z;
}

function renderSystemMonthHourHeatmap({
    plotId,
    rows,
    valueName,
    label,
    unit,
    precision = 3
}) {
    const z = makeMonthHourMatrix(rows, valueName);

    Plotly.newPlot(plotId, [{
        z: z,
        x: Array.from({ length: 24 }, (_, i) => i),
        y: Array.from({ length: 12 }, (_, i) => i + 1),
        type: "heatmap",
        xgap: 1,
        ygap: 1,
        colorscale: [
            [0, "#ffffff"],
            [0.5, "#fdae6b"],
            [1, "#d7301f"]
        ],
        colorbar: {
            title: {
                text: `${label} (${unit})`,
                side: "right"
            },
            len: 0.85,
            thickness: 12,
            outlinewidth: 0,
            tickwidth: 0.5
        },
        hovertemplate:
            `Month: %{y}<br>Hour: %{x}<br>${label}: %{z:.${precision}f} ${unit}<extra></extra>`
    }], {
        xaxis: { title: "Hour of day", showline: false, zeroline: false },
        yaxis: { title: "Month", autorange: "reversed", showline: false, zeroline: false },
        plot_bgcolor: "#f5f5f5",
        paper_bgcolor: "white",
        margin: { t: 20, l: 60, r: 120, b: 60 }
    }, { responsive: true });
}

window.renderSystemShortfallHeatmap = function(rows, energyUnit) {
    renderSystemMonthHourHeatmap({
        plotId: "system-shortfall-heatmap",
        rows: rows,
        valueName: "mean_shortfall",
        label: "Mean Shortfall",
        unit: energyUnit
    });
};

window.renderSystemNEUEHeatmap = function(rows) {
    renderSystemMonthHourHeatmap({
        plotId: "system-neue-heatmap",
        rows: rows,
        valueName: "neue",
        label: "Mean NEUE",
        unit: "ppm"
    });
};