*先把該節點先移除，停止對外服務後再做檢查

可朝三個面向檢查狀況

1. 前端流量分配問題
- LB 是否把過多流量導到這台？健康檢查設定、權重、sticky session 是否異常？
- 連線數比較：`ss -s` 看 ESTABLISHED 數量，是否 TIME_WAIT / CLOSE_WAIT 堆積、conntrack 表是否滿。

2. Server資源飽和(常見)
CPU;Memory;Disk I/O; Disk Space; Network issue
資源佔滿回應變慢容易造成TimeOut

3. 應用層問題
看AP Log, 及檢查APM trace，檢查是否有特定請求變慢。
