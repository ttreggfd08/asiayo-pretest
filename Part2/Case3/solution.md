服務活著但登不進去，最常見的問題是磁碟滿或 OOM（已在跑的 process 不受影響，但無法建立新連線）

AWS 有提供其他路徑可以遠端登入EC2，如SSM Session manager ; Serial Console ，替代SSH登入伺服器檢查問題 
如果以上方法都進不去的話，且服務可以暫停，那就是要停機把EBS 取出掛載到新的EC2上做修復及檢視問題

可能的原因有以下幾種
- 磁碟空間 sshd 無法建立 session/寫暫存檔，但已在跑的服務暫時不受影響
- 記憶體耗盡 / OOM無記憶體可 fork 新 sshd 連線 
- CPU / load 爆滿 系統無法及時給你 shell ，連線逾時，但服務仍緩慢回應 
- sshd 掛掉/設定錯誤，sshd crash、改 config 後 reload 失敗 
- 認證面問題，金鑰被刪、`authorized_keys`/家目錄權限改錯、`/etc/passwd` 損毀 

