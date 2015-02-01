#!/bin/bash

dir="$(dirname "$(readlink -f "$0")")"
for i in {1..4}; do
  "$dir/indicators" risk > "risk_$i" &
  "$dir/indicators" final_score > "final_score_$i"
done
