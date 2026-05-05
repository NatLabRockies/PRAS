window.renderEventPlots = function(systemData, stepSize, energyUnit, timeUnit) {
    const durations = systemData.duration;
    const energies = systemData.energy;
    const sampleIds = systemData.sample_id;

    Plotly.newPlot("duration-histogram", [{
        x: durations,
        type: "histogram",
        xbins: { size: stepSize },
        hovertemplate: "Duration: %{x}<br>Count: %{y}<extra></extra>"
    }], {
        title: "System Event Duration Distribution",
        xaxis: { title: `Duration (${timeUnit})` },
        yaxis: { title: "Number of events" },
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
            colorbar: { title: energyUnit }
        },
        hovertemplate:
            "Sample %{customdata}<br>Duration: %{x}<br>Energy: %{y:.2f} " + energyUnit + "<extra></extra>"
    }], {
        title: "System Event Energy vs Duration",
        xaxis: { title: `Duration (${timeUnit})` },
        yaxis: { title: `Energy (${energyUnit})` },
        margin: { t: 50, l: 70, r: 90, b: 60 }
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

        layout[xaxisName2] = { domain: [x0, x1], anchor: yref2, title: `Duration (${timeUnit})` };
        layout[yaxisName2] = { domain: [yScat0, yScat1], anchor: xref2, title: facetCol === 0 ? `Energy (${energyUnit})` : "" };

        const data = regionalData.get(region);

        traces.push({
            x: data.duration,
            type: "histogram",
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
                colorbar: idx === regions.length - 1 ? { title: energyUnit } : undefined
            },
            customdata: data.sample_id,
            hovertemplate:
                "Region: " + region + "<br>Sample %{customdata}<br>Duration: %{x}<br>Energy: %{y:.2f} " + energyUnit + "<extra></extra>"
        });

        layout.annotations.push({
            text: region,
            x: (x0 + x1) / 2,
            y: yHist1 + 0.03,
            xref: "paper",
            yref: "paper",
            showarrow: false,
            font: { size: 13 }
        });
    });

    Plotly.newPlot("regional-events-faceted-plot", traces, layout, { responsive: true });
};