# Secrets

Plaintext secrets live in `secrets.env`, which is ignored by git. The encrypted copy `secrets.env.enc` is
committed, so both machines stay in sync through `git pull`. The passphrase is never stored in the repository.

```sh
./scripts/secrets.sh unlock   # secrets.env.enc -> secrets.env   (asks for the passphrase)
./scripts/secrets.sh apply    # secrets.env     -> iOS xcconfig + Android properties
./scripts/secrets.sh lock     # secrets.env     -> secrets.env.enc (asks for the passphrase)
```

Windows without Git Bash: use `scripts\secrets.ps1` with the same three commands.

`apply` writes two files, both git-ignored:

| File | Used by |
|---|---|
| `ios/Config/Secrets.xcconfig` | Xcode build settings, injected into Info.plist as `SchoolAppKey` |
| `android/secrets.properties` | Gradle, exposed as `BuildConfig.SCHOOL_APP_KEY` |

Encryption is `openssl enc -aes-256-cbc -pbkdf2 -iter 200000 -salt`, available on macOS and in Git Bash on
Windows, so neither machine needs extra tooling.
