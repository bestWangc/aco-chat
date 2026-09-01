#!/usr/bin/env python3
"""按 UTC+8 日期导出 PancakeSwap V2 池子的 Swap 日志，每天一个 JSONL 文件。"""
import argparse, datetime as dt, json, os, sys, time, urllib.request

PAIR = "0xa25b52492b7177d115feec6dc09084b1c3952f93"
PUBLIC_RPCS = [
    "https://bnb-mainnet.g.alchemy.com/v2/5n-CO7afpWDLc5j1X6VD5cRlu2ndqvyZ",
]

def rpc(url, method, params):
    urls = url if isinstance(url, list) else [url]
    errors = []
    for endpoint in urls:
        try:
            req = urllib.request.Request(endpoint, json.dumps({"jsonrpc":"2.0","id":1,"method":method,"params":params}).encode(), {"Content-Type":"application/json"})
            with urllib.request.urlopen(req, timeout=60) as r: out = json.load(r)
            if "error" in out: raise RuntimeError(out["error"])
            return out["result"]
        except Exception as exc:
            errors.append(f"{endpoint}: {exc}")
    raise RuntimeError("所有 RPC 均失败: " + " | ".join(errors))

def block_at(url, timestamp, latest):
    lo, hi = 0, latest
    while lo < hi:
        mid = (lo + hi) // 2
        if int(rpc(url, "eth_getBlockByNumber", [hex(mid), False])["timestamp"], 16) < timestamp: lo = mid + 1
        else: hi = mid
    return lo

def main():
    ap = argparse.ArgumentParser(); ap.add_argument("--month", default=dt.datetime.now(dt.timezone.utc).strftime("%Y-%m")); ap.add_argument("--rpc", default=os.getenv("BSC_RPC", ",".join(PUBLIC_RPCS)), help="单个 RPC，或用逗号分隔多个 RPC"); ap.add_argument("--chunk", type=int, default=50, help="每次查询的区块数，公共 RPC 建议 10-100"); ap.add_argument("--delay", type=float, default=0.2, help="每个区块窗口后的停顿秒数"); ap.add_argument("--output", default="data/pancake-aldbnb"); a = ap.parse_args(); a.rpc = [x.strip() for x in a.rpc.split(",") if x.strip()]
    y, m = map(int, a.month.split("-")); local_start = dt.datetime(y,m,1); local_end = local_start.replace(year=y+1,month=1) if m==12 else local_start.replace(month=m+1); start = (local_start-dt.timedelta(hours=8)).replace(tzinfo=dt.timezone.utc); end = (local_end-dt.timedelta(hours=8)).replace(tzinfo=dt.timezone.utc)
    latest = int(rpc(a.rpc,"eth_blockNumber",[]),16); first = block_at(a.rpc,int(start.timestamp()),latest); last = block_at(a.rpc,int(end.timestamp()),latest); os.makedirs(a.output,exist_ok=True); handles={}
    block_cache = {}
    try:
        # 公共 BSC RPC 还限制单次返回日志条数，密集交易池使用小窗口。
        for begin in range(first,last,a.chunk):
            logs = rpc(a.rpc,"eth_getLogs",[{"address":PAIR,"fromBlock":hex(begin),"toBlock":hex(min(begin+a.chunk-1,last-1))}])
            if a.delay > 0: time.sleep(a.delay)
            for log in logs:
                if len(log["topics"]) != 3 or len(log["data"]) != 258: continue
                if log["blockNumber"] not in block_cache:
                    block_cache[log["blockNumber"]] = rpc(a.rpc,"eth_getBlockByNumber",[log["blockNumber"],False])
                when=dt.datetime.fromtimestamp(int(block_cache[log["blockNumber"]]["timestamp"],16),dt.timezone.utc)
                if not start <= when < end: continue
                d=log["data"][2:]; local=when+dt.timedelta(hours=8)
                row={"date_utc":when.strftime("%Y-%m-%d"),"datetime_utc":when.isoformat(),"date_utc8":local.strftime("%Y-%m-%d"),"datetime_utc8":local.isoformat(),"tx_hash":log["transactionHash"],"block":int(log["blockNumber"],16),"tx_index":int(log["transactionIndex"],16),"sender":"0x"+log["topics"][1][-40:],"to":"0x"+d[192:232],"amount0_in":str(int(d[0:64],16)),"amount1_in":str(int(d[64:128],16)),"amount0_out":str(int(d[128:192],16)),"amount1_out":str(int(d[192:256],16))}
                path=os.path.join(a.output,row["date_utc8"]+".jsonl"); handles.setdefault(path,open(path,"a",encoding="utf-8")); handles[path].write(json.dumps(row,ensure_ascii=False)+"\n")
    finally:
        for h in handles.values(): h.close()

if __name__ == "__main__":
    try: main()
    except Exception as e: print(f"导出失败: {e}",file=sys.stderr); raise SystemExit(1)
