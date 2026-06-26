#!/usr/bin/env python3
"""
Cluster-Lab Billing Dashboard
=============================
Slurm billing web interface。
查询 sacct Jobs History、计算Cost、展示集群Status。
"""

import subprocess
import re
import json
from datetime import datetime, timedelta
from flask import Flask, render_template_string, request, jsonify

app = Flask(__name__)

# ── 计费费率 ──
# 每 CPU 每小时的价格（单位：Kr/核时）
RATES = {
    "normal": 1.0,    # normal 队列：1.0 Kr/核时
    "debug":  0.05,   # debug  队列：0.05 Kr/核时
}

# ── HTML 模板 ──
TEMPLATE = r"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Cluster-Lab Billing</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: #f5f7fa;
            color: #1a1a2e;
            line-height: 1.6;
        }
        .header {
            background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%);
            color: white;
            padding: 2rem;
            text-align: center;
        }
        .header h1 { font-size: 2rem; margin-bottom: 0.5rem; }
        .header p { opacity: 0.8; font-size: 0.95rem; }
        .container { max-width: 1200px; margin: 0 auto; padding: 2rem; }
        .stats-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
            gap: 1rem;
            margin-bottom: 2rem;
        }
        .stat-card {
            background: white;
            border-radius: 12px;
            padding: 1.5rem;
            box-shadow: 0 2px 8px rgba(0,0,0,0.06);
            text-align: center;
        }
        .stat-card .value {
            font-size: 2rem;
            font-weight: 700;
            color: #0f3460;
        }
        .stat-card .label {
            font-size: 0.85rem;
            color: #666;
            margin-top: 0.3rem;
        }
        .stat-card.green .value { color: #27ae60; }
        .stat-card.blue .value { color: #2980b9; }
        .stat-card.gold .value { color: #f39c12; }
        .section {
            background: white;
            border-radius: 12px;
            padding: 1.5rem;
            box-shadow: 0 2px 8px rgba(0,0,0,0.06);
            margin-bottom: 2rem;
        }
        .section h2 {
            font-size: 1.3rem;
            margin-bottom: 1rem;
            padding-bottom: 0.5rem;
            border-bottom: 2px solid #eee;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            font-size: 0.9rem;
        }
        th {
            background: #f8f9fa;
            padding: 0.75rem;
            text-align: left;
            font-weight: 600;
            color: #555;
            border-bottom: 2px solid #dee2e6;
        }
        td {
            padding: 0.75rem;
            border-bottom: 1px solid #eee;
        }
        tr:hover { background: #f8f9fa; }
        .badge {
            display: inline-block;
            padding: 0.2rem 0.6rem;
            border-radius: 999px;
            font-size: 0.75rem;
            font-weight: 600;
        }
        .badge.COMPLETED { background: #d4edda; color: #155724; }
        .badge.RUNNING  { background: #cce5ff; color: #004085; }
        .badge.PENDING  { background: #fff3cd; color: #856404; }
        .badge.FAILED   { background: #f8d7da; color: #721c24; }
        .badge.CANCELLED { background: #e2e3e5; color: #383d41; }
        .cost { font-weight: 600; }
        .form-row {
            display: flex;
            gap: 1rem;
            align-items: center;
            margin-bottom: 1rem;
            flex-wrap: wrap;
        }
        input, select {
            padding: 0.5rem 0.75rem;
            border: 1px solid #ddd;
            border-radius: 6px;
            font-size: 0.9rem;
        }
        button {
            padding: 0.5rem 1.5rem;
            background: #0f3460;
            color: white;
            border: none;
            border-radius: 6px;
            cursor: pointer;
            font-size: 0.9rem;
        }
        button:hover { background: #1a4a7a; }
        .nav-links {
            display: flex;
            gap: 1rem;
            margin-bottom: 1rem;
        }
        .nav-links a {
            color: #2980b9;
            text-decoration: none;
            font-weight: 500;
        }
        .nav-links a:hover { text-decoration: underline; }
        .footer {
            text-align: center;
            color: #999;
            font-size: 0.8rem;
            padding: 2rem;
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>🖥️ Cluster-Lab Billing System</h1>
        <p>Slurm HPC Cluster · Job Billing &amp; Usage</p>
    </div>
    <div class="container">
        <div class="nav-links">
            <a href="/">📊 Dashboard</a>
            <a href="/jobs">📋 Jobs History</a>
            <a href="/usage">📈 Usage</a>
            <a href="/api/jobs" target="_blank">🔗 API</a>
        </div>

        <!-- CONTENT_PLACEHOLDER -->

        <div class="footer">
            Cluster-Lab · Slurm {{ slurm_version }}
        </div>
    </div>
</body>
</html>"""

DASHBOARD_TEMPLATE = TEMPLATE + r"""
{% block content %}
<div class="stats-grid">
    <div class="stat-card blue">
        <div class="value">{{ stats.nodes_online }}</div>
        <div class="label">Online Nodes</div>
    </div>
    <div class="stat-card green">
        <div class="value">{{ stats.jobs_completed }}</div>
        <div class="label">Jobs Done</div>
    </div>
    <div class="stat-card gold">
        <div class="value">{{ stats.total_cost }} Kr</div>
        <div class="label">Total Cost</div>
    </div>
    <div class="stat-card">
        <div class="value">{{ stats.total_cpu_hours }} h</div>
        <div class="label">Total CPU Hours</div>
    </div>
</div>

<div class="section">
    <h2>Recent Jobs</h2>
    <div class="form-row">
        <form method="get" action="/">
            <label>Show last
                <select name="hours" onchange="this.form.submit()">
                    <option value="1" {% if hours == 1 %}selected{% endif %}>1 hour</option>
                    <option value="6" {% if hours == 6 %}selected{% endif %}>6 hours</option>
                    <option value="24" {% if hours == 24 %}selected{% endif %}>24 hours</option>
                    <option value="168" {% if hours == 168 %}selected{% endif %}>7 days</option>
                    <option value="720" {% if hours == 720 %}selected{% endif %}>30 days</option>
                </select>
            </label>
        </form>
    </div>
    {% if jobs %}
    <table>
        <thead>
            <tr>
                <th>JobID</th>
                <th>Name</th>
                <th>User</th>
                <th>Partition</th>
                <th>Node</th>
                <th>CPU</th>
                <th>Duration</th>
                <th>Status</th>
                <th>Cost</th>
            </tr>
        </thead>
        <tbody>
            {% for j in jobs %}
            <tr>
                <td>{{ j.jobid }}</td>
                <td>{{ j.jobname }}</td>
                <td>{{ j.user }}</td>
                <td>{{ j.partition }}</td>
                <td>{{ j.nodelist }}</td>
                <td>{{ j.ncpus }}</td>
                <td>{{ j.elapsed }}</td>
                <td><span class="badge {{ j.state }}">{{ j.state }}</span></td>
                <td class="cost">{{ "%.2f"|format(j.cost) }} Kr</td>
            </tr>
            {% endfor %}
        </tbody>
    </table>
    {% else %}
    <p style="color: #999; text-align: center; padding: 2rem;">No jobs found</p>
    {% endif %}
</div>

<div class="section">
    <h2>Cluster Nodes</h2>
    <table>
        <thead>
            <tr><th>Node</th><th>Status</th><th>Partition</th><th>CPU</th><th>Used Mem</th><th>Total Mem</th></tr>
        </thead>
        <tbody>
            {% for n in nodes %}
            <tr>
                <td>{{ n.name }}</td>
                <td><span class="badge {{ n.state }}">{{ n.state }}</span></td>
                <td>{{ n.partition }}</td>
                <td>{{ n.cpus }}</td>
                <td>{{ n.mem_used }} MB</td>
                <td>{{ n.mem_total }} MB</td>
            </tr>
            {% endfor %}
        </tbody>
    </table>
</div>
{% endblock %}
"""

JOBS_TEMPLATE = TEMPLATE + r"""
{% block content %}
<div class="section">
    <h2>Jobs History</h2>
    <div class="form-row">
        <form method="get" action="/jobs">
            <label>时间范围：
                <select name="hours" onchange="this.form.submit()">
                    <option value="1" {% if hours == 1 %}selected{% endif %}>Last 1 hour</option>
                    <option value="6" {% if hours == 6 %}selected{% endif %}>Last 6 hours</option>
                    <option value="24" {% if hours == 24 %}selected{% endif %}>Last 24 hours</option>
                    <option value="168" {% if hours == 168 %}selected{% endif %}>Last 7 days</option>
                    <option value="all" {% if hours == 'all' %}selected{% endif %}>All</option>
                </select>
            </label>
        </form>
    </div>
    {% if jobs %}
    <table>
        <thead>
            <tr>
                <th>JobID</th>
                <th>Name</th>
                <th>User</th>
                <th>Partition</th>
                <th>QoS</th>
                <th>Node</th>
                <th>CPU</th>
                <th>Submit Time</th>
                <th>Duration</th>
                <th>Status</th>
                <th>Cost</th>
            </tr>
        </thead>
        <tbody>
            {% for j in jobs %}
            <tr>
                <td>{{ j.jobid }}</td>
                <td>{{ j.jobname }}</td>
                <td>{{ j.user }}</td>
                <td>{{ j.partition }}</td>
                <td>{{ j.qos }}</td>
                <td>{{ j.nodelist }}</td>
                <td>{{ j.ncpus }}</td>
                <td>{{ j.submit_time }}</td>
                <td>{{ j.elapsed }}</td>
                <td><span class="badge {{ j.state }}">{{ j.state }}</span></td>
                <td class="cost">{{ "%.2f"|format(j.cost) }} Kr</td>
            </tr>
            {% endfor %}
        </tbody>
    </table>
    {% else %}
    <p style="color: #999; text-align: center; padding: 2rem;">No jobs found</p>
    {% endif %}
</div>
{% endblock %}
"""

USAGE_TEMPLATE = TEMPLATE + r"""
{% block content %}
<div class="section">
    <h2>User Usage Stats</h2>
    {% if usage %}
    <table>
        <thead>
            <tr>
                <th>User</th>
                <th>Jobs</th>
                <th>Total CPU Hours</th>
                <th>Total Cost</th>
            </tr>
        </thead>
        <tbody>
            {% for u in usage %}
            <tr>
                <td>{{ u.user }}</td>
                <td>{{ u.jobs }}</td>
                <td>{{ "%.2f"|format(u.cpu_hours) }} h</td>
                <td class="cost">{{ "%.2f"|format(u.cost) }} Kr</td>
            </tr>
            {% endfor %}
        </tbody>
    </table>
    {% else %}
    <p style="color: #999; text-align: center; padding: 2rem;">暂无统计</p>
    {% endif %}
</div>
{% endblock %}
"""

# ── 辅助函数 ──

def run_cmd(cmd):
    """安全运行 shell 命令，返回 stdout 或 None"""
    try:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=10)
        return result.stdout
    except Exception as e:
        print(f"CMD ERROR: {cmd}: {e}")
        return None


def parse_elapsed(elapsed_str):
    """将 slurm 时长格式转为秒数"""
    if not elapsed_str or elapsed_str == "00:00:00":
        return 0
    parts = elapsed_str.split("-")
    if len(parts) == 2:
        days = int(parts[0])
        time_part = parts[1]
    else:
        days = 0
        time_part = parts[0]

    t = time_part.split(":")
    if len(t) == 3:
        return days * 86400 + int(t[0]) * 3600 + int(t[1]) * 60 + int(t[2])
    elif len(t) == 2:
        return days * 86400 + int(t[0]) * 3600 + int(t[1]) * 60
    return 0


def format_duration(seconds):
    """格式化时长显示"""
    days = seconds // 86400
    hours = (seconds % 86400) // 3600
    minutes = (seconds % 3600) // 60
    secs = seconds % 60
    if days > 0:
        return f"{days}d {hours:02d}:{minutes:02d}:{secs:02d}"
    else:
        return f"{hours:02d}:{minutes:02d}:{secs:02d}"


def calculate_cost(ncpus, elapsed_seconds, qos="normal"):
    """根据 CPU 数和时长计算Cost"""
    cpu_hours = ncpus * (elapsed_seconds / 3600)
    rate = RATES.get(qos, RATES["normal"])
    return cpu_hours * rate


def get_slurm_version():
    """获取 Slurm 版本号（不含 slurm 前缀）"""
    out = run_cmd("sinfo -V 2>/dev/null")
    version = out.strip() if out else "N/A"
    return version.replace("slurm ", "").strip()


def get_node_info():
    """获取Node信息"""
    out = run_cmd("sinfo -N -o '%n|%t|%P|%e|%m|%C' --noheader 2>/dev/null")
    if not out:
        return []

    seen = {}
    for line in out.strip().split("\n"):
        parts = line.split("|")
        if len(parts) < 6:
            continue
        name = parts[0].strip()
        partition = parts[2].strip().rstrip("*")
        cpu_str = parts[5].strip()
        try:
            cpu_parts = cpu_str.split("/")
            total_cpus = int(cpu_parts[-1])
        except (ValueError, IndexError):
            total_cpus = 0
        if name not in seen:
            seen[name] = {
                "name": name,
                "state": parts[1].strip(),
                "partition": partition,
                "mem_free": int(parts[3]) if parts[3].strip().isdigit() else 0,
                "mem_total": int(parts[4]) if parts[4].strip().isdigit() else 0,
                "mem_used": int(parts[4]) - int(parts[3]) if parts[3].strip().isdigit() and parts[4].strip().isdigit() else 0,
                "cpus": total_cpus,
            }
        else:
            # Merge partitions for nodes in multiple partitions
            existing = seen[name]
            existing_partitions = existing["partition"].split(", ")
            if partition not in existing_partitions:
                existing["partition"] = ", ".join(existing_partitions + [partition])
    return list(seen.values())


def get_jobs(hours=24):
    """获取作业列表"""
    # sacct options
    start_time = None
    if hours != "all":
        start_time = (datetime.now() - timedelta(hours=int(hours))).strftime("%Y-%m-%dT%H:%M:%S")

    cmd = (
        "sacct --noheader --parsable2 --format=JobID,JobName,User,Partition,"
        "QOS,NodeList,AllocCPUS,Submit,Elapsed,State "
        "-X -a"
    )
    if start_time:
        cmd += f" --starttime={start_time}"

    out = run_cmd(cmd)
    if not out:
        return []

    jobs = []
    for line in out.strip().split("\n"):
        parts = line.split("|")
        if len(parts) < 10:
            continue

        try:
            jobid = parts[0].strip()
            # 跳过 .batch 和 .extern 子作业
            if "." in jobid:
                continue

            ncpus = int(parts[6]) if parts[6] else 1
            elapsed_str = parts[8]
            elapsed_sec = parse_elapsed(elapsed_str)
            qos = parts[4] if parts[4] else "normal"
            state = parts[9] if parts[9] else "UNKNOWN"

            jobs.append({
                "jobid": jobid,
                "jobname": parts[1] if parts[1] else "(none)",
                "user": parts[2] if parts[2] else "root",
                "partition": parts[3] if parts[3] else "normal",
                "qos": qos,
                "nodelist": parts[5] if parts[5] else "N/A",
                "ncpus": ncpus,
                "submit_time": parts[7] if parts[7] else "-",
                "elapsed": format_duration(elapsed_sec),
                "elapsed_sec": elapsed_sec,
                "state": state,
                "cost": calculate_cost(ncpus, elapsed_sec, qos),
            })
        except (ValueError, IndexError):
            continue

    return jobs


def get_dashboard_stats(jobs):
    """计算仪表盘统计数据"""
    total_cpu_hours = sum(j["ncpus"] * (j["elapsed_sec"] / 3600) for j in jobs)
    total_cost = sum(j["cost"] for j in jobs)
    completed = sum(1 for j in jobs if j["state"] == "COMPLETED")

    # 获取Node数
    nodes = get_node_info()
    online = sum(1 for n in nodes if n["state"] in ("idle", "mix", "alloc"))

    return {
        "nodes_online": online,
        "jobs_completed": completed,
        "total_cost": round(total_cost, 2),
        "total_cpu_hours": round(total_cpu_hours, 1),
    }


def get_usage_by_user(jobs):
    """按User统计用量"""
    usage = {}
    for j in jobs:
        user = j["user"]
        if user not in usage:
            usage[user] = {"user": user, "jobs": 0, "cpu_hours": 0.0, "cost": 0.0}
        usage[user]["jobs"] += 1
        cpu_h = j["ncpus"] * (j["elapsed_sec"] / 3600)
        usage[user]["cpu_hours"] += cpu_h
        usage[user]["cost"] += j["cost"]
    return sorted(usage.values(), key=lambda x: x["cost"], reverse=True)


# ── 路由 ──

@app.route("/")
def dashboard():
    hours = request.args.get("hours", 24, type=int)
    jobs = get_jobs(hours)
    stats = get_dashboard_stats(jobs)
    nodes = get_node_info()
    return render_template_string(
        DASHBOARD_TEMPLATE,
        stats=stats,
        jobs=jobs[:20],  # 只显示最近 20 条
        nodes=nodes,
        hours=hours,
        slurm_version=get_slurm_version(),
    )


@app.route("/jobs")
def jobs():
    hours = request.args.get("hours", "24")
    jobs = get_jobs(hours)
    return render_template_string(
        JOBS_TEMPLATE,
        jobs=jobs,
        hours=hours,
        slurm_version=get_slurm_version(),
    )


@app.route("/usage")
def usage():
    jobs = get_jobs(hours=720)  # 默认全部（30 天）
    usage_data = get_usage_by_user(jobs)
    return render_template_string(
        USAGE_TEMPLATE,
        usage=usage_data,
        slurm_version=get_slurm_version(),
    )


@app.route("/api/jobs")
def api_jobs():
    """JSON API 接口"""
    hours = request.args.get("hours", 24, type=int)
    jobs = get_jobs(hours)
    return jsonify({
        "total": len(jobs),
        "jobs": [{
            "jobid": j["jobid"],
            "jobname": j["jobname"],
            "user": j["user"],
            "state": j["state"],
            "ncpus": j["ncpus"],
            "elapsed": j["elapsed"],
            "cost": j["cost"],
        } for j in jobs[:100]],
    })


if __name__ == "__main__":
    import sys
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 5000
    print(f"🚀 Cluster-Lab Billing Dashboard starting on port {port}...")
    app.run(host="0.0.0.0", port=port, debug=False)
