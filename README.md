# letsencrypt-summary

# letsencryptを使ってcurlで発生する問題

2021/09/30以降 openssl 1.0.2を使用しており、ルート証明書に  
「DST Root CA X3」が含まれている場合、証明書のチェックに失敗する  
openssl 1.1.0 以降では上記の証明書でもエラーにならない。  

「DST Root CA X3」を含めないようにするにはcertbotのオプションに--preferred-chain "ISRG Root X1"を足す  

https://www.openssl.org/blog/blog/2021/09/13/LetsEncryptRootCertExpire/  
https://qiita.com/tana6/items/46976e2ff5c875c13327  

意図した証明書のパスになっているかはブラウザでは確認できない。  
直接opensslコマンドなどで確認する。  

## 設定が効いている証明書
```
openssl s_client -connect <example.com>:443  < /dev/null
depth=2 C = US, O = Internet Security Research Group, CN = ISRG Root X1
verify return:1
depth=1 C = US, O = Let's Encrypt, CN = R3
verify return:1
depth=0 CN = <example.com>
verify return:1
DONE
CONNECTED(00000003)
---
Certificate chain
 0 s:CN = <example.com>
   i:C = US, O = Let's Encrypt, CN = R3
 1 s:C = US, O = Let's Encrypt, CN = R3
   i:C = US, O = Internet Security Research Group, CN = ISRG Root X1
---
```

## デフォルトの証明書

```
openssl s_client -connect <example.com>:443  < /dev/null
depth=2 C = US, O = Internet Security Research Group, CN = ISRG Root X1
verify return:1
depth=1 C = US, O = Let's Encrypt, CN = R3
verify return:1
depth=0 CN = <example.com>
verify return:1
DONE
CONNECTED(00000003)
---
Certificate chain
 0 s:CN = <example.com>
   i:C = US, O = Let's Encrypt, CN = R3
 1 s:C = US, O = Let's Encrypt, CN = R3
   i:C = US, O = Internet Security Research Group, CN = ISRG Root X1
 2 s:C = US, O = Internet Security Research Group, CN = ISRG Root X1
   i:O = Digital Signature Trust Co., CN = DST Root CA X3
---
```

# windowsのcurlの仕様

Windowsに標準でインストールされているcurlはバックエンドにWinSSLを使用しており、  
失効サーバーのチェックを行っている。  
Linuxのcurlやopensslバックエンドでは行われていない？模様。  

またletsencryptの失効サーバーはocspで確認しており  
期限は1週間。  
※仕様としてはcrlは7日以上10日以下、ocspは4日以上10日以下ということらしい  
https://www.digicert.co.jp/welcome/pdf/wp_ssl_handshake.pdf  

証明書の期限が切れていなくても失効サーバーの更新期間を過ぎているとエラーになる。  
そのため、クライアントの日付をいじって確認する場合、この期間を過ぎないように調整する必要がある。  
※つまり1週間分くらいしか確認できない  
```
* schannel: next InitializeSecurityContext failed: Unknown error (0x80092013) - 失効サーバーがオフラインのため、失効の関数は失効を確認できませんでした。
```

windowsのocspやcrlはキャッシュが効くため、wiresharkなどで通信を行っているか確認したほうがいい。  
https://jp.globalsign.com/support/faq/598.html  

また失効一覧更新時間を過ぎても、サーバークライアントで同期が取れていない場合を考慮して  
一定時間のずれを許容するようなオプションがある場合がある※クライアント実装。  
Windowsのcurlは少なくともデフォルトでは許容されていなさそう。  

opensslの場合は5分。  
validity_period   
http://home.att.ne.jp/theta/diatom/ocsp%281%29.html  

# OCSPの挙動

サーバー側の設定でOCSPのレスポンスまで返してくれる場合、  
クライアント側でOCSPをチェックしに行くことはなさそう。  
この場合クライアントの日付を変えてもocspに影響はないため、純粋に証明書の有効期限のチェックのみになる。  

## OCSPのレスポンスを返すサーバー

```
# sniを設定しているサーバーだとservernameが必要
# https://qiita.com/greymd/items/5d2fc55430105620a550
openssl s_client -connect <example.com>:443 -servername <example.com> -status < /dev/null
...

OCSP response:
======================================
OCSP Response Data:
    OCSP Response Status: successful (0x0)
    Response Type: Basic OCSP Response
    Version: 1 (0x0)
    Responder Id: 87B2E6D0DFDF0CE32D97D22408A9508F270B9069
    Produced At: Sep 21 14:16:16 2021 GMT
    Responses:
    Certificate ID:
      Hash Algorithm: sha1
      Issuer Name Hash: B469DA139862735BAC570F57C2A9E3A25DAF076C
      Issuer Key Hash: 87B2E6D0DFDF0CE32D97D22408A9508F270B9069
      Serial Number: BC358FF50CFBFD23A1EFE916500F77B4
    Cert Status: good
    This Update: Sep 21 14:16:16 2021 GMT
    Next Update: Sep 28 14:16:16 2021 GMT

...

```

## OCSPのレスポンスを返さないサーバー

```
# sniを設定しているサーバーだとservernameが必要
# https://qiita.com/greymd/items/5d2fc55430105620a550
openssl s_client -connect <example.com>:443 -servername <example.com> -status < /dev/null
...

OCSP response: no response sent

...
```

apacheの場合はSSLUseStaplingで設定  

https://www.cybertrust.co.jp/sureserver/support/files/apache_ocsp.pdf  
https://blog.apar.jp/linux/8041/  
https://qiita.com/ariaki/items/78ed2d3810ad17f72398  
