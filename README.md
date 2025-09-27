# k8s_setup_rh

RHEL/AlmaLinux/Rocky 9 系で Kubernetes v1.34 を kubeadm + CRI-O + flannel で構築するためのスクリプト集です。開発/検証用途を想定しており、一部で SELinux/Firewalld を無効化します。プロダクション利用時は十分にセキュリティを調整してください。

## 特徴
- kubeadm ベースのクラスタ構築（複数 Control Plane + LB を想定）
- コンテナランタイムは CRI-O
- CNI は flannel（PodCIDR: 10.244.0.0/16）
- 便利ツール・周辺（kubectl/helm/ArgoCD CLI、code-server、etcdctl、PostgreSQL クライアント、Discord 通知、NFS）

## 想定環境
- OS: RHEL 9 / AlmaLinux 9 / Rocky Linux 9 互換
- Kubernetes: v1.34 系
- ノード例（`setting.sh` の `/etc/hosts` サンプル）
  - dev-code-01, dev-lb-01
  - dev-k8s-master-01/02/03
  - dev-k8s-worker-01/02/03
  - dev-nfs-01

## スクリプト一覧（概要）
- 初期設定
  - `setting.sh` タイムゾーン/chrony、/etc/hosts 設定、SELinux 無効化、NIC/IP 設定、再起動
- Kubernetes 構築
  - `ha_proxy.sh` Control Plane 向け HAProxy の設定/起動
  - `cp_install.sh` 初回 Control Plane ノードの kubeadm init と join 設定生成（CRI-O/kubelet/kubeadm/kubectl の導入含む）
  - `wk_install.sh` Worker ノードの前提パッケージ導入（CRI-O/kubelet/kubeadm/kubectl）
  - `flannel_install.sh` flannel の Helm 導入（PodCIDR 10.244.0.0/16）
- 運用補助
  - `k8s-operation.sh` cloudflared、Docker、Helm、kubectl、ArgoCD CLI などの導入
  - `argocd_install.sh` ArgoCD 本体のデプロイと初期パスワード取得/ポートフォワード
  - `code-server_install.sh` code-server + nginx でのリバースプロキシ設定
  - `etcdctl_install.sh` etcdctl の導入
  - `psql16_client.sh` PostgreSQL 16 クライアントの導入
  - `discord_notify.sh` Discord Webhook に起動/停止通知を送る systemd サービス
  - `nfs_server_install.sh` NFS サーバの導入/エクスポート設定
  - `nfs_client_install.sh` NFS クライアントの導入/マウント設定

## クイックスタート
1) 事前準備（全ノード）
- root または sudo で実行してください。
- `setting.sh` を各ノードで実行（NIC/PRIVATE_IP/GATEWAY_IP を環境に合わせて修正）
  ```bash
  vi setting.sh  # NIC, PRIVATE_IP, GATEWAY_IP を修正
  bash setting.sh
  ```
- 再起動後、基本パッケージやネットワーク設定が整います。

2) ロードバランサ（LB ノード）
- `ha_proxy.sh` を編集し、LB の公開 IP/ホスト名と Control Plane の実 IP/ホスト名を反映
  ```bash
  vi ha_proxy.sh  # HA_PROXY_SERVER, CONTROL_PLANE_IPS を自環境に合わせる
  bash ha_proxy.sh
  ```

3) 初回 Control Plane ノード（例: dev-k8s-master-01）
- `cp_install.sh` を実行
  - kubeadm の init を行い、以下のファイルをホームディレクトリに生成します：
    - `~/init_kubeadm.yaml`（初期化設定）
    - `~/join_kubeadm_cp.yaml`（他の CP 用 join 設定）
    - `~/join_kubeadm_wk.yaml`（Worker 用 join 設定）
  ```bash
  vi cp_install.sh  # KUBE_API_SERVER_IP, バージョンなど必要なら調整
  bash cp_install.sh
  ```
- CNI を導入（flannel）
  ```bash
  bash flannel_install.sh
  ```

4) 追加 Control Plane ノード（例: dev-k8s-master-02/03）
- 初回ノードで生成された `~/join_kubeadm_cp.yaml` を配布し、各ノードで join
  ```bash
  kubeadm join --config ~/join_kubeadm_cp.yaml
  ```

5) Worker ノード（例: dev-k8s-worker-01/02/03）
- 前提導入後に join
  ```bash
  bash wk_install.sh
  kubeadm join --config ~/join_kubeadm_wk.yaml
  ```

6) 動作確認
```bash
kubectl get nodes -o wide
kubectl get pods -A
```

## 運用系ツール（任意）
- 基本ツール一括
  ```bash
  bash k8s-operation.sh
  ```
- ArgoCD をクラスターへ導入
  ```bash
  bash argocd_install.sh
  # 初期パスワード表示
  # ポートフォワード: https://localhost:3000
  ```
- code-server（デフォルトでは認証なし + nginx で 80 公開。必ず適切に保護してください）
  ```bash
  vi code-server_install.sh  # server_name 等を環境に合わせて修正
  bash code-server_install.sh
  ```
- NFS サーバ/クライアント
  ```bash
  # サーバ側
  vi nfs_server_install.sh  # SHARE_ADDRESS/PV 数など
  bash nfs_server_install.sh

  # クライアント側
  vi nfs_client_install.sh  # NFS_SERVER_IP/NFS_SERVER_DIR/SHARE_DIRECTORY
  bash nfs_client_install.sh
  ```
- Discord 通知（Webhook URL 必須）
  ```bash
  vi discord_notify.sh  # DISCORD_WEBHOOK_URL を設定
  bash discord_notify.sh
  ```
- etcdctl / psql クライアント
  ```bash
  bash etcdctl_install.sh
  bash psql16_client.sh
  ```

## 事前に調整すべき変数（重要）
- `setting.sh`:
  - `NIC`, `PRIVATE_IP`, `GATEWAY_IP`（ネットワーク/再起動あり）
- `ha_proxy.sh`:
  - `HA_PROXY_SERVER`, `CONTROL_PLANE_IPS`（LB/CP の IP/ホスト名）
- `cp_install.sh`:
  - `KUBE_API_SERVER_IP`, `MANIFEST_VERSION`, `KUBERNETES_VERSION`, `REPO_KUBERNETES_VERSION`
- `wk_install.sh`:
  - `KUBERNETES_VERSION`, `REPO_KUBERNETES_VERSION`
- `flannel_install.sh`:
  - `--set podCidr="10.244.0.0/16"`（`cp_install.sh` の `podSubnet` と一致させる）
- `code-server_install.sh`:
  - nginx の `server_name`, 認証方式（デフォルトは `auth: none`）
- `nfs_*`:
  - サーバ側: `SHARE_DIRECTORY`, `PV_DIRECTORYS`, `SHARE_ADDRESS`
  - クライアント側: `NFS_SERVER_IP`, `NFS_SERVER_DIR`, `SHARE_DIRECTORY`
- `discord_notify.sh`:
  - `DISCORD_WEBHOOK_URL`

## セキュリティ/注意事項
- 一部スクリプトで SELinux/Firewalld を無効化します。要件に応じて適切に有効化/ルール設定を行ってください。
- `code-server` はデフォルトで認証無効化（`auth: none`）になっています。公開環境では必ず認証やネットワーク制限を加えてください。
- 実行前に各スクリプト内容と変数を確認し、環境に合わせて編集してください。

## トラブルシューティングのヒント
- ノード状態の確認
  ```bash
  kubectl get nodes -o wide
  kubectl -n kube-flannel get pods -o wide
  ```
- サービスログ確認
  ```bash
  journalctl -u crio -f
  journalctl -u kubelet -f
  ```
- 失敗時のリセット（実行注意）
  ```bash
  kubeadm reset -f
  systemctl restart crio kubelet
  ```
- ルーティング/iptables 関連（CNI）
  - `br_netfilter` と `net.ipv4.ip_forward` の設定が適用されているか確認

## ライセンス
- 本リポジトリは Apache License 2.0 の下で公開しています。詳細は `LICENSE` を参照してください。

## 参考
- Kubernetes: https://kubernetes.io/
- CRI-O: https://cri-o.io/
- flannel: https://github.com/flannel-io/flannel
- kubeadm: https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/
