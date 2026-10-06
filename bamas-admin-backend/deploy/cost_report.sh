#!/usr/bin/env bash
#
# What will this server cost per month once the free credits run out?
#
#   bash deploy/cost_report.sh
#
# Run it ON the server. It needs no AWS keys: everything about the machine
# itself comes from the instance metadata service, which only the instance
# can reach. The one optional part (S3 size) uses the instance's IAM role.
#
# It prints the three things that actually decide the bill -- instance
# type, total EBS GiB, and whether the CPU is burning burst credits --
# plus an estimate. The estimate is a guide; the authoritative number is
# Cost Explorer, because that reflects this account's real rates.
#
# Nothing here changes anything. Read-only, safe to run on a live box.

set -uo pipefail

line() { printf '%s\n' "------------------------------------------------------------"; }
say()  { printf '%-26s %s\n' "$1" "$2"; }

# ---------------------------------------------------------------- metadata
# IMDSv2: get a token first. -s so a failure stays quiet, and every lookup
# falls back to "?" rather than killing the script, in case IMDS is hardened.
TOKEN=$(curl -s -m 3 -X PUT "http://169.254.169.254/latest/api/token" \
          -H "X-aws-ec2-metadata-token-ttl-seconds: 120" 2>/dev/null)
imds() {
  if [ -n "${TOKEN:-}" ]; then
    curl -s -m 3 -H "X-aws-ec2-metadata-token: $TOKEN" \
      "http://169.254.169.254/latest/meta-data/$1" 2>/dev/null || echo "?"
  else
    curl -s -m 3 "http://169.254.169.254/latest/meta-data/$1" 2>/dev/null || echo "?"
  fi
}

ITYPE=$(imds instance-type)
IID=$(imds instance-id)
AZ=$(imds placement/availability-zone)
REGION=${AZ%?}
PUBIP=$(imds public-ipv4)
LIFECYCLE=$(imds instance-life-cycle)

line
echo "SERVER"
line
say "Instance type"   "${ITYPE:-?}"
say "Instance id"     "${IID:-?}"
say "Region / AZ"     "${REGION:-?} / ${AZ:-?}"
say "Purchase"        "${LIFECYCLE:-on-demand}"
say "Public IPv4"     "${PUBIP:-none}"
say "vCPU / RAM"      "$(nproc) vCPU / $(free -m | awk '/^Mem:/{printf "%.1f GiB", $2/1024}')"
say "Uptime"          "$(uptime -p 2>/dev/null || uptime)"

# ------------------------------------------------------------------- disks
# lsblk reports each attached EBS volume's provisioned size, which is what
# AWS bills -- NOT how full the filesystem is. A half-empty 100 GiB volume
# costs the same as a full one, which is how leftover volumes quietly add
# money to a bill nobody is watching.
line
echo "DISKS  (billed on PROVISIONED size, not on how full they are)"
line
lsblk -b -d -o NAME,SIZE,TYPE 2>/dev/null | awk 'NR==1 || $3=="disk"' | \
  awk 'NR==1{print "  NAME            SIZE"; next}
       {printf "  %-15s %6.0f GiB\n", $1, $2/1024/1024/1024}'

TOTAL_GIB=$(lsblk -b -d -n -o SIZE,TYPE 2>/dev/null | awk '$2=="disk"{s+=$1} END{printf "%.0f", s/1024/1024/1024}')
say "TOTAL provisioned" "${TOTAL_GIB:-?} GiB"
echo
echo "  Filesystem usage (for comparison -- this is NOT what is billed):"
df -h --output=target,size,used,avail,pcent 2>/dev/null | grep -vE "tmpfs|loop|^Mounted" | sed 's/^/    /'
echo
echo "  If TOTAL provisioned is much bigger than what is used, there may be"
echo "  a volume attached that nothing needs. Check EC2 > Volumes for any"
echo "  volume in state 'available' (attached to nothing) -- those are pure"
echo "  waste and are billed in full."

# --------------------------------------------------------------- cpu burst
# The single biggest surprise on a t2/t3 bill. In unlimited mode, sustained
# CPU above the instance's baseline is billed per vCPU-hour as "CPUCredits",
# on TOP of the instance price. One heavy week of imports or an index build
# can double a month's bill without changing anything about the server.
line
echo "CPU"
line
say "Load average"   "$(awk '{print $1", "$2", "$3}' /proc/loadavg)"

read -r _ u n s i rest < /proc/stat; t1=$((u+n+s+i)); i1=$i
sleep 5
read -r _ u n s i rest < /proc/stat; t2=$((u+n+s+i)); i2=$i
BUSY=$(awk -v dt=$((t2-t1)) -v di=$((i2-i1)) 'BEGIN{ if(dt>0) printf "%.1f", (1-di/dt)*100; else print "?" }')
say "CPU busy (5s sample)" "${BUSY}%"

case "${ITYPE:-}" in
  t2.*|t3.*|t3a.*|t4g.*)
    # Baselines: micro 10%, small 20%, medium 20% (per the T3 docs).
    case "${ITYPE}" in
      *.nano)   BASE=5  ;;
      *.micro)  BASE=10 ;;
      *.small)  BASE=20 ;;
      *.medium) BASE=20 ;;
      *)        BASE=30 ;;
    esac
    say "Burstable baseline" "~${BASE}% sustained CPU is free"
    echo
    if awk -v b="$BUSY" -v base="$BASE" 'BEGIN{exit !(b+0 > base+0)}' 2>/dev/null; then
      echo "  >> CPU is ABOVE the free baseline right now. If it stays here, you"
      echo "     are paying surplus CPU credits on top of the instance price."
      echo "     Find what is busy:  top -b -n1 | head -20"
    else
      echo "  OK: below baseline, so no surplus CPU credits are accruing at this"
      echo "  moment. That is a snapshot, not the month -- the month's figure is"
      echo "  in CloudWatch, metric CPUSurplusCreditsCharged (see the end)."
    fi
    ;;
  "") : ;;
  *)  say "Burstable" "no -- fixed performance, no CPU credit risk" ;;
esac

# -------------------------------------------------------------- memory/svc
line
echo "MEMORY AND SERVICES"
line
free -h | sed 's/^/  /'
echo
for svc in bamasandstore8 store8 mongod nginx; do
  printf '  %-20s %s\n' "$svc" "$(systemctl is-active "$svc" 2>/dev/null || echo 'not installed')"
done

# -------------------------------------------------------------------- s3
line
echo "S3  (uses the instance IAM role; skipped if it has no permission)"
line
if command -v aws >/dev/null 2>&1; then
  for b in bamasandstore8s3; do
    OUT=$(aws s3 ls "s3://$b" --recursive --summarize 2>/dev/null | tail -2)
    if [ -n "$OUT" ]; then
      echo "  s3://$b"
      echo "$OUT" | sed 's/^/    /'
    else
      echo "  s3://$b -- could not read (no permission, or empty)"
    fi
  done
else
  echo "  aws cli not installed -- check the bucket size in the S3 console"
fi

# ------------------------------------------------------------------- bill
line
echo "ESTIMATED MONTHLY COST  (ap-southeast-2 list prices, 744 h)"
line
cat <<'NOTE'
  These are LIST prices, used only to show the shape of the bill. Your real
  rates are whatever your account is charged -- confirm against Cost Explorer
  (steps printed below). Taxes/GST are extra and are NOT included here.
NOTE
echo
python3 - "$ITYPE" "${TOTAL_GIB:-0}" "${PUBIP:-}" <<'PY' 2>/dev/null || echo "  (python3 not available -- work it out from the figures above)"
import sys
itype, gib, pubip = sys.argv[1], float(sys.argv[2] or 0), sys.argv[3]

# ap-southeast-2 on-demand, Linux, per hour. Only the sizes plausible for
# this box are listed; anything else prints as unknown rather than guessing.
RATES = {
    "t3.nano": 0.0066, "t3.micro": 0.0132, "t3.small": 0.0264,
    "t3.medium": 0.0528, "t3.large": 0.1056,
    "t3a.micro": 0.0119, "t3a.small": 0.0238, "t3a.medium": 0.0475,
    "t2.micro": 0.0146, "t2.small": 0.0292, "t2.medium": 0.0584,
}
GP3_PER_GIB = 0.096   # ap-southeast-2 gp3 storage
IPV4_PER_HR = 0.005   # every public IPv4, Elastic or not
HOURS = 744

rows = []
rate = RATES.get(itype)
if rate:
    rows.append(("EC2 %s (744 h)" % itype, rate * HOURS))
else:
    rows.append(("EC2 %s -- rate unknown" % itype, None))

rows.append(("EBS gp3 %.0f GiB" % gib, gib * GP3_PER_GIB))
if pubip:
    rows.append(("Public IPv4", IPV4_PER_HR * HOURS))
rows.append(("S3 + data transfer (typical)", 0.50))

total = 0.0
unknown = False
for label, amt in rows:
    if amt is None:
        print("  %-34s %s" % (label, "?"))
        unknown = True
    else:
        print("  %-34s $%7.2f" % (label, amt))
        total += amt

print("  " + "-" * 44)
if unknown:
    print("  %-34s $%7.2f + instance" % ("SUBTOTAL (pre-tax)", total))
else:
    print("  %-34s $%7.2f" % ("TOTAL pre-tax, per month", total))
    print("  %-34s ~INR %s" % ("at ~86 INR/USD", format(int(total * 86), ",")))
    print()
    print("  Plus any CPU surplus credits, which are NOT in this figure and")
    print("  are what make a quiet month and a busy month differ.")
PY

# -------------------------------------------------------------- next steps
line
echo "THE AUTHORITATIVE NUMBER -- do this in the AWS console"
line
cat <<'NOTE'
  The estimate above is arithmetic. These two pages are facts about YOUR
  account, and together they answer "what do I pay when the credits end?".

  1) WHAT YOU WILL PAY  --  Billing > Cost Explorer
       Date range : Last 3 months,  Granularity : Monthly
       Advanced options > Cost type > "Unblended cost"
     Unblended cost IGNORES credits. So the monthly figure you see there is
     already what you will be charged once the credits are gone. You do not
     have to wait and find out.
     Then switch Cost type to "Net unblended cost": that is what you are
     actually paying today. The gap between the two is the credit.

  2) HOW LONG THE CREDITS LAST  --  Billing > Credits
     Note the expiry date and the amount remaining. Current AWS free-tier
     credits expire 6 months from the date the account was created, or when
     they are used up, whichever comes first.

  3) WHERE IT GOES  --  Cost Explorer, Group by > Usage Type
     Filter Service = EC2-Other. If you see "CPUCredits:t3" with real money
     against it, that is burst CPU, not infrastructure -- it comes from heavy
     one-off work and it goes away when the work stops.

  4) THE MONTH'S CPU BURST, EXACTLY  --  CloudWatch > Metrics > EC2
       > Per-Instance Metrics > CPUSurplusCreditsCharged
       statistic Sum, period 1 day
     All zeros = no burst charges at all this month.

  5) SET A BUDGET SO THIS NEVER SURPRISES YOU  --  Billing > Budgets
     Monthly cost budget, alert at 80% actual AND 100% forecasted.
     The forecast alert is the one that catches a bad month in week one.
NOTE
line
