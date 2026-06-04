# OpenCode 実行ガイド

`OpenCode` は、コード生成に特化したAIツールです。以下のガイドラインに従って、効果的にOpenCodeを活用しましょう。

## 実行

OpenCodeを実行するには、ターミナルで以下のコマンドを入力します。

```bash
opencode
```

## Amazon Bedrockでの実行

### 前提条件

1. OpenCodeを使用するには、AWSアカウントが必要です。

  1. AWSコンソールにアクセスし、IAMユーザーを作成してください。
    - コンソールアクセスを有効にしてください。
    - 適切な権限を付与してください。
      - マネージドポリシー: IAMUserChangePassword (パスワード変更の権限)
      - マネージドポリシー: SignInLocalDevelopmentAccess (ローカル開発用のサインイン権限)
      - カスタマーポリシー: mfa-control-policy (MFA管理の権限)
      ```json
      {
          "Version": "2012-10-17",
          "Statement": [
              {
                  "Sid": "AllowIndividualUserToManageTheirOwnMFA",
                  "Effect": "Allow",
                  "Action": [
                      "iam:CreateVirtualMFADevice",
                      "iam:DeleteVirtualMFADevice",
                      "iam:DeactivateMFADevice",
                      "iam:EnableMFADevice",
                      "iam:ResyncMFADevice",
                      "iam:ListMFADevices"
                  ],
                  "Resource": [
                      "arn:aws:iam::*:mfa/${aws:username}",
                      "arn:aws:iam::*:user/${aws:username}"
                  ]
              },
              {
                  "Sid": "BlockMostAccessUnlessSignedInWithMFA",
                  "Effect": "Deny",
                  "NotAction": [
                      "iam:CreateVirtualMFADevice",
                      "iam:DeleteVirtualMFADevice",
                      "iam:DeactivateMFADevice",
                      "iam:EnableMFADevice",
                      "iam:ResyncMFADevice",
                      "iam:ListMFADevices"
                  ],
                  "Resource": "*",
                  "Condition": {
                      "BoolIfExists": {
                          "aws:MultiFactorAuthPresent": "false"
                      }
                  }
              }
          ]
      }
      ```
      - カスタマーポリシー: bedrock-model-list-policy (Amazon Bedrockで利用可能なモデルのリストを取得するための権限)
      ```json
      {
        "Version": "2012-10-17",
        "Statement": [
          {
            "Effect": "Allow",
            "Action": [
              "bedrock:ListFoundationModels",
              "bedrock:ListInferenceProfiles"
            ],
            "Resource": [
              "*"
            ]
          },
          {
            "Sid": "AllowMarketplaceForModelAccess",
            "Effect": "Allow",
            "Action": [
              "aws-marketplace:ViewSubscriptions",
              "aws-marketplace:Subscribe"
            ],
            "Resource": "*",
            "Condition": {
              "StringEquals": {
                "aws:CalledViaLast": "bedrock.amazonaws.com"
              }
            }
          }
        ]
      }
      ```
  2. セキュリティ認証情報タブの、多要素認証 (MFA)で、MFAデバイスを設定してください。
    - 設定しなくてもOpenCodeは使用できますが、セキュリティの観点から設定を推奨しています。

2. WSL上にAWS CLIがインストールされ、適切に設定されている必要があります。

version 2.32.x以降になっていることを確認し、SSOログインを行います。

```bash
aws --version
```

最初のセットアップでは、AWS CLIのSSOログインを使用して認証を行う必要があります。以下のコマンドを実行して、AWS SSOにログインし、現在の認証情報を確認してください。`<AWS_PROFILE_NAME>`は、AWS CLIで設定したプロファイル名に置き換えてください。

```bash
aws sso login --profile <AWS_PROFILE_NAME>
```

AWS SSOログイン時にリージョンを指定する必要がある場合は、以下のリージョンを指定してください。東京リージョン以外の場合は、適切なリージョンを指定してください。

AWS_REGION: `ap-northeast-1`

最初のセットアップが完了したら、以下のコマンドを使用して、現在の認証情報を確認します。`<AWS_PROFILE_NAME>`は、AWS CLIで設定したプロファイル名に置き換えてください。

```bash
aws sts get-caller-identity --profile <AWS_PROFILE_NAME>
```

3. モデルを選択します。

以下のコマンドを実行して、Amazon Bedrockで利用可能なモデルのリストを取得します。

```bash
aws bedrock list-inference-profiles --profile claude-code-user > aws-bedrock-list-inference-profiles.json
```

以下のようなJSONが出力されます。

```json
{
  "inferenceProfileSummaries": [
    {
      "inferenceProfileName": "APAC Nova Micro",
      "description": "Routes requests to Nova Micro in ap-southeast-2, ap-northeast-1, ap-south-1, ap-northeast-2, ap-southeast-1 and ap-northeast-3.",
      "createdAt": "2025-02-22T10:00:00+00:00",
      "updatedAt": "2025-07-02T19:54:59.078437+00:00",
      "inferenceProfileArn": "arn:aws:bedrock:ap-northeast-1:415771680036:inference-profile/apac.amazon.nova-micro-v1:0",
      "models": [
        {
          "modelArn": "arn:aws:bedrock:ap-southeast-2::foundation-model/amazon.nova-micro-v1:0"
        },
        {
          "modelArn": "arn:aws:bedrock:ap-northeast-1::foundation-model/amazon.nova-micro-v1:0"
        },
        {
          "modelArn": "arn:aws:bedrock:ap-south-1::foundation-model/amazon.nova-micro-v1:0"
        },
        {
          "modelArn": "arn:aws:bedrock:ap-northeast-2::foundation-model/amazon.nova-micro-v1:0"
        },
        {
          "modelArn": "arn:aws:bedrock:ap-southeast-1::foundation-model/amazon.nova-micro-v1:0"
        },
        {
          "modelArn": "arn:aws:bedrock:ap-northeast-3::foundation-model/amazon.nova-micro-v1:0"
        }
      ],
      "inferenceProfileId": "apac.amazon.nova-micro-v1:0",
      "status": "ACTIVE",
      "type": "SYSTEM_DEFINED"
    }
  ]
}
```

カスタマーポリシーを作成します。
- modelsのARNを、Resourceに追加します。

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "bedrock:InvokeModel",
        "bedrock:InvokeModelWithResponseStream"
      ],
      "Resource": [
        "arn:aws:bedrock:ap-southeast-2::foundation-model/amazon.nova-micro-v1:0",
        "arn:aws:bedrock:ap-northeast-1::foundation-model/amazon.nova-micro-v1:0",
        "arn:aws:bedrock:ap-south-1::foundation-model/amazon.nova-micro-v1:0",
        "arn:aws:bedrock:ap-northeast-2::foundation-model/amazon.nova-micro-v1:0",
        "arn:aws:bedrock:ap-southeast-1::foundation-model/amazon.nova-micro-v1:0",
        "arn:aws:bedrock:ap-northeast-3::foundation-model/amazon.nova-micro-v1:0"
      ]
    }
  ]
}
```

### 設定

OpenCodeを使用する前に、プロジェクトのルートディレクトリに `opencode.json` ファイルを作成し、以下のように設定します。
- MODEL_NAMEは、`inferenceProfileId` を指定します。
- AWS_REGIONは、モデルが利用可能なリージョンを指定します。
- AWS_PROFILE_NAMEは、AWS CLIで設定したプロファイル名を指定します。


```json
{
  "$schema": "https://opencode.ai/config.json",
  "model": "<MODEL_NAME>",
  "provider": {
    "amazon-bedrock": {
      "options": {
        "region": "<AWS_REGION>",
        "profile": "<AWS_PROFILE_NAME>"
      }
    }
  }
}
```
