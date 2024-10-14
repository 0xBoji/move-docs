# Step 1

Open Terminal inside this project folder and run these below command to create profiles. The accounts are created to Devnet by dafault.

Create source account.
```
aptos init
```
Create admin-account.

```
aptos init --profile admin-account
```
Create nft-receiver.
```
aptos init --profile nft-receiver
```

# Step 2

After creating the Aptos profiles, a folder .aptos is created with the file config.yaml inside. Open this file.

Update source code
Step 1.1

From config.yaml, copy account address of default profile and then open move.toml file. In the source_addr put your account address make sure to add 0x in the front of address so address will be like this source_addr = "0x19ce4969ac99e5d01f0be1413a8af3abc3143945372366765ef5e7eb25d1004e"

Step 1.2

From config.yaml, copy account address of admin-account and then open move.toml file. In the admin_addr put your account address make sure to add 0x in the front of address so address will be like this admin_addr = "0xe17365770306373bb547e2204b556edd55debd01141b4935b9e4f092e3195cb0"

Step 1.3

Change the NFT collection settings in sources/minting.move