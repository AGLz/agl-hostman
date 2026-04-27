#!/usr/bin/env python3
"""
CMN Resolution 4.963 vs 5.272 Visualization Generator
Generates comparative charts and visualizations based on the analysis data.
"""

import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
import numpy as np
import pandas as pd
from datetime import datetime, timedelta
import json
import os

# Set style
plt.style.use('seaborn-v0_8')
plt.rcParams['figure.figsize'] = (12, 8)
plt.rcParams['font.size'] = 10
plt.rcParams['axes.titlesize'] = 14
plt.rcParams['axes.labelsize'] = 12

def create_governance_distribution():
    """Create pie chart showing current governance level distribution"""
    fig, ax = plt.subplots(figsize=(10, 8))

    sizes = [40, 40, 15, 5]  # Nível I, II, III, IV percentages
    labels = ['Nível I\n(Basic)', 'Nível II\n(Enhanced)', 'Nível III\n(Advanced)', 'Nível IV\n(Sophisticated)']
    colors = ['#d62728', '#2ca02c', '#ff7f0e', '#1f77b4']
    explode = (0.05, 0.05, 0.05, 0.1)

    wedges, texts, autotexts = ax.pie(sizes, explode=explode, labels=labels, colors=colors,
                                    autopct='%1.1f%%', shadow=True, startangle=90)

    ax.set_title('Current RPPS Governance Level Distribution', fontsize=16, fontweight='bold')

    # Add legend
    ax.legend(wedges, [f'{label} - {size}%' for label, size in zip(labels, sizes)],
              title="Governance Levels", loc="center left", bbox_to_anchor=(1, 0, 0.5, 1))

    plt.tight_layout()
    plt.savefig('/mnt/overpower/apps/dev/agl/agl-hostman/docs/governance_distribution.png',
                dpi=300, bbox_inches='tight')
    plt.close()

def create_investment_limits_comparison():
    """Create grouped bar chart comparing investment limits"""
    fig, ax = plt.subplots(figsize=(14, 8))

    categories = ['Renda\nFixa', 'Renda\nVariável', 'Estruturados', 'Imobiliários', 'Exterior']
    nivel_ii = [100, 40, 15, 0, 0]
    nivel_iii = [100, 50, 25, 20, 10]
    nivel_iv = [100, 60, 20, 20, 20]

    x = np.arange(len(categories))
    width = 0.25

    rects1 = ax.bar(x - width, nivel_ii, width, label='Nível II', color='#2ca02c')
    rects2 = ax.bar(x, nivel_iii, width, label='Nível III', color='#ff7f0e')
    rects3 = ax.bar(x + width, nivel_iv, width, label='Nível IV', color='#1f77b4')

    ax.set_ylabel('Investment Limit (%)')
    ax.set_title('Investment Limits by Governance Level', fontsize=16, fontweight='bold')
    ax.set_xticks(x)
    ax.set_xticklabels(categories, rotation=0)
    ax.legend()
    ax.grid(True, alpha=0.3)

    # Add value labels on bars
    def add_value_labels(rects):
        for rect in rects:
            height = rect.get_height()
            ax.annotate(f'{height}%',
                        xy=(rect.get_x() + rect.get_width() / 2, height),
                        xytext=(0, 3),
                        textcoords="offset points",
                        ha='center', va='bottom')

    add_value_labels(rects1)
    add_value_labels(rects2)
    add_value_labels(rects3)

    plt.tight_layout()
    plt.savefig('/mnt/overpower/apps/dev/agl/agl-hostman/docs/investment_limits_comparison.png',
                dpi=300, bbox_inches='tight')
    plt.close()

def create_timeline_gantt():
    """Create Gantt chart showing implementation timeline"""
    fig, ax = plt.subplots(figsize=(14, 8))

    phases = [
        ('Assessment & Foundation', '2026-02', '2026-07', '#d62728'),
        ('Nível II Certification', '2026-08', '2027-01', '#2ca02c'),
        ('Nível III Advancement', '2027-02', '2027-07', '#ff7f0e'),
        ('Nível IV Achievement', '2027-08', '2028-01', '#1f77b4')
    ]

    y_pos = np.arange(len(phases))

    for i, (name, start, end, color) in enumerate(phases):
        start_date = datetime.strptime(start, '%Y-%m')
        end_date = datetime.strptime(end, '%Y-%m')
        duration = (end_date - start_date).days / 30.0

        ax.barh(y_pos[i], duration, left=0, height=0.6, color=color, alpha=0.8)
        ax.text(duration/2, y_pos[i], name, ha='center', va='center', fontweight='bold')

        # Add dates
        ax.text(-2, y_pos[i], start, va='center', ha='right')
        ax.text(duration + 1, y_pos[i], end, va='center', ha='left')

    ax.set_yticks(y_pos)
    ax.set_yticklabels([])
    ax.set_xlabel('Timeline (Months)')
    ax.set_title('24-Month Implementation Roadmap', fontsize=16, fontweight='bold')
    ax.grid(True, alpha=0.3)

    # Add budget info
    budget_text = ('Budget Ranges:\n'
                  'Phase 1: R$ 500K-1M\n'
                  'Phase 2: R$ 1.5M-3M\n'
                  'Phase 3: R$ 2M-4M\n'
                  'Phase 4: R$ 3M-5M')

    ax.text(0.02, 0.98, budget_text, transform=ax.transAxes,
            verticalalignment='top', bbox=dict(boxstyle='round', facecolor='wheat', alpha=0.8))

    plt.tight_layout()
    plt.savefig('/mnt/overpower/apps/dev/agl/agl-hostman/docs/timeline_gantt.png',
                dpi=300, bbox_inches='tight')
    plt.close()

def create_impact_radar():
    """Create radar chart showing impact assessment"""
    fig, ax = plt.subplots(figsize=(10, 10), subplot_kw=dict(projection='polar'))

    categories = ['Governance\nCapability', 'Investment\nReturns', 'Risk\nManagement',
                 'Market\nPosition', 'Innovation\nPotential']

    N = len(categories)
    angles = [n / float(N) * 2 * np.pi for n in range(N)]
    angles += angles[:1]

    # Data for each governance level
    nivel_i = [20, 30, 25, 20, 15]
    nivel_ii = [50, 50, 60, 40, 30]
    nivel_iii = [75, 70, 75, 60, 60]
    nivel_iv = [95, 85, 90, 80, 85]

    nivel_i += nivel_i[:1]
    nivel_ii += nivel_ii[:1]
    nivel_iii += nivel_iii[:1]
    nivel_iv += nivel_iv[:1]

    ax.plot(angles, nivel_i, 'o-', linewidth=2, label='Nível I', color='#d62728')
    ax.fill(angles, nivel_i, alpha=0.1, color='#d62728')

    ax.plot(angles, nivel_ii, 'o-', linewidth=2, label='Nível II', color='#2ca02c')
    ax.fill(angles, nivel_ii, alpha=0.1, color='#2ca02c')

    ax.plot(angles, nivel_iii, 'o-', linewidth=2, label='Nível III', color='#ff7f0e')
    ax.fill(angles, nivel_iii, alpha=0.1, color='#ff7f0e')

    ax.plot(angles, nivel_iv, 'o-', linewidth=2, label='Nível IV', color='#1f77b4')
    ax.fill(angles, nivel_iv, alpha=0.1, color='#1f77b4')

    ax.set_xticks(angles[:-1])
    ax.set_xticklabels(categories)
    ax.set_ylim(0, 100)
    ax.set_title('Impact Assessment by Governance Level', fontsize=16, fontweight='bold', pad=20)
    ax.legend(loc='upper right', bbox_to_anchor=(1.3, 1.0))

    plt.tight_layout()
    plt.savefig('/mnt/overpower/apps/dev/agl/agl-hostman/docs/impact_radar.png',
                dpi=300, bbox_inches='tight')
    plt.close()

def create_financial_projection():
    """Create financial projection chart"""
    fig, ax = plt.subplots(figsize=(12, 8))

    years = ['2026', '2027', '2028', '2029', '2030']
    x = np.arange(len(years))

    # Implementation costs (cumulative)
    nivel_ii_costs = [0.5, 2.0, 2.0, 2.0, 2.0]
    nivel_iii_costs = [1.0, 4.0, 4.0, 4.0, 4.0]
    nivel_iv_costs = [1.5, 6.0, 10.0, 10.0, 10.0]

    # Return projections (annual)
    nivel_ii_returns = [0, 8, 10, 12, 12]
    nivel_iii_returns = [0, 12, 18, 20, 20]
    nivel_iv_returns = [0, 18, 28, 30, 30]

    # Plot costs
    ax2 = ax.twinx()

    line1 = ax.plot(x, nivel_ii_costs, 's--', label='Nível II Costs', color='#2ca02c', linewidth=2)
    line2 = ax.plot(x, nivel_iii_costs, 'o--', label='Nível III Costs', color='#ff7f0e', linewidth=2)
    line3 = ax.plot(x, nivel_iv_costs, 'd--', label='Nível IV Costs', color='#1f77b4', linewidth=2)

    line4 = ax2.plot(x, nivel_ii_returns, 's-', label='Nível II Returns', color='#2ca02c', linewidth=2)
    line5 = ax2.plot(x, nivel_iii_returns, 'o-', label='Nível III Returns', color='#ff7f0e', linewidth=2)
    line6 = ax2.plot(x, nivel_iv_returns, 'd-', label='Nível IV Returns', color='#1f77b4', linewidth=2)

    ax.set_xlabel('Year')
    ax.set_ylabel('Implementation Cost (BRL)', color='black')
    ax2.set_ylabel('Annual Return (%)', color='black')
    ax.set_title('Financial Projections: Costs vs Returns', fontsize=16, fontweight='bold')

    # Combine legends
    lines = line1 + line2 + line3 + line4 + line5 + line6
    labels = [l.get_label() for l in lines]
    ax.legend(lines, labels, loc='upper left')

    ax.grid(True, alpha=0.3)
    ax.set_xticks(x)
    ax.set_xticklabels(years)

    plt.tight_layout()
    plt.savefig('/mnt/overpower/apps/dev/agl/agl-hostman/docs/financial_projection.png',
                dpi=300, bbox_inches='tight')
    plt.close()

def create_segment_evolution():
    """Create area chart showing portfolio segment evolution"""
    fig, ax = plt.subplots(figsize=(12, 8))

    years = ['Before CMN 5.272', 'Nível II', 'Nível III', 'Nível IV']

    # Portfolio composition percentages
    renda_fixa = [90, 60, 30, 20]
    renda_variavel = [10, 40, 50, 60]
    estruturados = [0, 0, 5, 10]
    imobiliarios = [0, 0, 10, 5]
    exterior = [0, 0, 5, 5]

    # Create stacked area chart
    ax.fill_between(years, 0, renda_fixa, label='Renda Fixa', alpha=0.8, color='#1f77b4')
    ax.fill_between(years, renda_fixa, np.array(renda_fixa) + np.array(renda_variavel),
                   label='Renda Variável', alpha=0.8, color='#ff7f0e')
    ax.fill_between(years, np.array(renda_fixa) + np.array(renda_variavel),
                   np.array(renda_fixa) + np.array(renda_variavel) + np.array(estruturados),
                   label='Estruturados', alpha=0.8, color='#2ca02c')
    ax.fill_between(years, np.array(renda_fixa) + np.array(renda_variavel) + np.array(estruturados),
                   np.array(renda_fixa) + np.array(renda_variavel) + np.array(estruturados) + np.array(imobiliarios),
                   label='Imobiliários', alpha=0.8, color='#d62728')
    ax.fill_between(years, np.array(renda_fixa) + np.array(renda_variavel) + np.array(estruturados) + np.array(imobiliarios),
                   100, label='Exterior', alpha=0.8, color='#9467bd')

    ax.set_ylabel('Portfolio Allocation (%)')
    ax.set_xlabel('Governance Level / Time Period')
    ax.set_title('Portfolio Evolution: CMN 4.963 to 5.272', fontsize=16, fontweight='bold')
    ax.legend(loc='upper right', bbox_to_anchor=(1.15, 1))
    ax.grid(True, alpha=0.3)
    ax.set_ylim(0, 100)

    plt.tight_layout()
    plt.savefig('/mnt/overpower/apps/dev/agl/agl-hostman/docs/segment_evolution.png',
                dpi=300, bbox_inches='tight')
    plt.close()

def main():
    """Generate all visualizations"""
    print("Generating CMN Resolution 4.963 vs 5.272 visualizations...")

    # Create docs directory if it doesn't exist
    os.makedirs('/mnt/overpower/apps/dev/agl/agl-hostman/docs', exist_ok=True)

    # Generate all charts
    create_governance_distribution()
    print("✓ Governance distribution chart created")

    create_investment_limits_comparison()
    print("✓ Investment limits comparison chart created")

    create_timeline_gantt()
    print("✓ Timeline Gantt chart created")

    create_impact_radar()
    print("✓ Impact radar chart created")

    create_financial_projection()
    print("✓ Financial projection chart created")

    create_segment_evolution()
    print("✓ Segment evolution chart created")

    print("\nAll visualizations have been generated successfully!")
    print("Location: /mnt/overpower/apps/dev/agl/agl-hostman/docs/")

if __name__ == "__main__":
    main()