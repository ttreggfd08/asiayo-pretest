先跟開發單位敲定 log 欄位規格(level / service / trace_id / timestamp 命名與型別)
並在 Elastic 建好 index template(定義 mapping)+ ILM 政策(rollover / 保留天數)
後續部署 / 設定 Fluent Bit DaemonSet 取得Node內的Log (/var/log/containers/*.log)
程式運行後會輸出JSON類型Log到 stdout
Kibana 建 Data View ; 常用 Search(如 level:ERROR) ; Dashboard(如錯誤率, API延遲) ; 設定主動式提醒Alert
最後在提供Kibana相關權限讓開發者能自助排查
