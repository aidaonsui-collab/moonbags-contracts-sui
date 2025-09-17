import { TransactionBlock } from "@mysten/sui.js/transactions";
import readline from "readline";
import { packageAddress, processResult, configAddress } from "./utils";

// Token data from the provided list
const tokenData = [
    { tokenAddress: "0x08463c24690de2984440f242e39323bd19837f0f7178675fb008ee016da82d92::kcrab::KCRAB", listedPoolId: "0xfd4f9061b36c7170b05368c7e65547018a74170d16d6059d3d5ec7e01796806c" },
    { tokenAddress: "0x08a92ba877b181714780fd2a36ea0ae508c870ea9285d2e383ad64546f5f87ed::nown::NOWN", listedPoolId: "0xc262432c904d4317715adffdf285de25e5f98cc5cba83d486d95f19dd5411738" },
    { tokenAddress: "0x89b8f1c88e658171c409bfa428e344acd3028368eb19efbf7753434656b67be9::ash::ASH", listedPoolId: "0x106a8b105b5804ea3da3055c2666e158658358841b178935040ee9f05711fca5" },
    { tokenAddress: "0x5c105d7ddbeaa4a4a63e3fbb6efb59a2fcad2519daf934fbc48186198a6fe028::toge::TOGE", listedPoolId: "0xbb16939ee1a1027c4dc8771cb894285f8930066c256f3421c8e94755ce7e97d9" },
    { tokenAddress: "0x98e1c47c60fbcca7e425f862ddedb6aa91b406261d27e2d3b25620da9a1bf466::two::TWO", listedPoolId: "0x3d8606a40afb3cb662f7a6f6656507d7047345030db11cb7388d66c0725e1285" },
    { tokenAddress: "0x2775b665fa5837592088e648e98e0597d79caedcc3039d4dc3a47dc647044134::ita::ITA", listedPoolId: "0x73cab69f2ebd6f6e00b05ffdd3c2e59c74922e51daf34f37b462007262998b97" },
    { tokenAddress: "0x3766e534b5dc6cdb7defd998debf19f72565f4a7b8224e36b050f690b71a8819::boom::BOOM", listedPoolId: "0xae74d149e064bdd2ca0fb3f9dc32157d8653457875618eb6e75054a3949e9043" },
    { tokenAddress: "0x0212c13fa071fcdae9f1f51bc4d820fa9f2396934478758bb278015e7781c154::rocket::ROCKET", listedPoolId: "0x744eb8f8ef80f26586894f147ff35c3cd3515f9d0ed5ed894425d43248dcf166" },
    { tokenAddress: "0xe611631f54b5c1976fefa0d43514411e091b7e65010041471b835ee16ab1f697::prntszn::PRNTSZN", listedPoolId: "0x0eea5bed79b879d25ac07853865d3f0de865eb9c20e8c6ef4b9e7201fc6c693e" },
    { tokenAddress: "0xe0fce1ed43ddac672a33adf823ae5402675dddf96edf1079ee81ee0cd2964066::kila::KILA", listedPoolId: "0xdd099077af49a2fb66332be51c4d02134569c764706a2aa9a327e2afa90ea422" },
    { tokenAddress: "0x7fa1b21949b8e4fa7174d6221a6b2d1260caf3bed660f450c7e4e975bfa96db0::mews::MEWS", listedPoolId: "0xc6ca5fdcf6e5d1d5f13202aeef95d51292634e19c2360e6f9368463cb19fd720" },
    { tokenAddress: "0x15fa2fa2f7fafee6af04fb732cf7f8352e830b73fa5274e333f724c4884ba030::meowth::MEOWTH", listedPoolId: "0x2cb267fec8b4a934f254a4daef4261288fe4e746257bde41f75347c1d825beac" },
    { tokenAddress: "0xc3dd9247da9104fc81fa5a77159cb669d218df09ffa08d600af236a676c62636::bogie::BOGIE", listedPoolId: "0x113f227a05a5a9db1fbc2770eb66f63f8d74c723d66fdd740016bccbfd955bc7" },
    { tokenAddress: "0x8b6e2ca7bafe1f0144dea2ea167abc614de69e73c4acb11d1bf8d90fcb2aeebc::zengar::ZENGAR", listedPoolId: "0x9773de9af68e07dc46e5a058ce09f4d4a1f21af90bb035f848ce98f4ea9aa4e3" },
    { tokenAddress: "0x467e4f4642c56c51c382f362c4f00a6550903a04bdfe680daef6db048fde1b30::magi::MAGI", listedPoolId: "0xc5602b1df8ae716a0ed52e00fe69e632cd405a8d785de8039d77f468cd8b7420" },
    { tokenAddress: "0x6f2071362016c6db900dfc95feba3169fa1ca006d097646ca6a522549873c6aa::suichu::SUICHU", listedPoolId: "0x7bd1c6dfbcd75301d574a226b1e05316cfc647f88082e3b94c57ed736a74916c" },
    { tokenAddress: "0x7d8709aa9247855e7f1b7958241444d0d74e0f2174ac50e4076822189d5f7305::smud::SMUD", listedPoolId: "0xcbf70d4b8a4c7fb1487000f3ebd61dd31f20764ca058f5d9a48528dd4e4052be" },
    { tokenAddress: "0x12f4f6f3b8352e1d1ba1df4d6941e8720b8e37342f95ebb7780898621f7692ab::jelly::JELLY", listedPoolId: "0x01506619fd093590d6ed47ef6ff292be70974239cf45e10e550c9b0eb125b186" },
    { tokenAddress: "0x5fad71cd86dfb03f3941571835b54fb2a94364ae54ac7f816224837ff424b662::king::KING", listedPoolId: "0xd22b04ec838c86ecfb929892496cf6d7e8e95e7b99bd387f799a09070a89e4a6" },
    { tokenAddress: "0x150a3765f43bee5e67f8faa04ad8802aab8fe8656d270198b55f825d4816cffe::wet::WET", listedPoolId: "0x0bb40f4a0c74231e353cad444f95169eadeb76fe803f656140ebd360f5029095" },
    { tokenAddress: "0xa609fc1f44c85613edfce6ca90e8a0a2572c20b6b002971967549837eda18586::freak::FREAK", listedPoolId: "0xc42f41f6b18649986a8d9030f8e68aee12672031be54346d72991398873af541" },
    { tokenAddress: "0x7b888393d6a552819bb0a7f878183abaf04550bfb9546b20ea586d338210826f::moon::MOON", listedPoolId: "0x7a82db9825a3a0456192940f42a0042b565ca8a75fc6bfeee3ce315199d532c9" },
    { tokenAddress: "0x7bd673d1b980fc2f1c922f91395c325561a675fc2f349c8ffcff7d03bdbeadc8::boost::BOOST", listedPoolId: "0x3d257271b793f24e79ff7018529dc6c511679232ee2753b3636734aef563516e" },
    { tokenAddress: "0xb95cd98747c3cc31fc78c4dfd277896ed13b0666f15e84c8cc64f157a0dfb091::pupui::PUPUI", listedPoolId: "0xe305e85b1c9cd9361059585bcb11ee4410dd2f154e028f38a83ff5abb03f1f3b" },
    { tokenAddress: "0x20d97b22c2f49c2848a9712cdf86ee734a344b89e03b755c663512cee91d1c91::suiffy::SUIFFY", listedPoolId: "0xa8bea2beb79f070e36ede281100f46f98654b998c22012cb592ca6b4e16b2fdd" },
    { tokenAddress: "0xedad9e72cc6ce23180c81fdf135f9a03ba189545ce83f69f1b0a1f551def3469::zard::ZARD", listedPoolId: "0xff4ef9a2df177a2483077b0a545a1aaf5b41cf3b1b7bbf6f9db218529e9b87fe" },
    { tokenAddress: "0x7ed4017ee8e94e6c481933e2e4447921cf9b8ac33dedfc9705b275628dd48eb4::pendu::PENDU", listedPoolId: "0x3f25071773d3393370d65321cd7b4836ba1ee55eb9fdbd514ea71b7d935c5ce5" },
    { tokenAddress: "0x689e949fc29d388e1d672e0335f5336fc8f97ca6d862806b3d619709b114666d::trealsuiguy::TREALSUIGUY", listedPoolId: "0x2aaa9bd707fd5dd2f23d3670229b50158f1bc50900d6cfa2562916b2881a6013" },
    { tokenAddress: "0xde09cdacc0d81564c758a833bf7db89a4a1db029d8d2298520aaef0a710ce39c::suivee::SUIVEE", listedPoolId: "0x16e0dad1120bf64f9082e2a13827cdcafd26c8c9c6e37e2bf97b4ddee69262b2" },
    { tokenAddress: "0x99df571c611598304c5c2b43fc3f58bd97095566788d576eca53b1aad6a53c95::poke::POKE", listedPoolId: "0xa7da6a5ab0018f712c77b68f0d491848885b9407581618a166412746edcbb822" },
    { tokenAddress: "0x603b12df519c36ecc09f7b02154a67d9cbd791426ca44e009a8ca727f3026297::vape::VAPE", listedPoolId: "0x39e722a9dbafc7f740850dc3d743c030524be21881f734ffd40ad4370972940f" },
    { tokenAddress: "0x4e14c1a959d8b6540d71708a97bd8672245614074d07ad7b2233baf43cc43342::hbibi::HBIBI", listedPoolId: "0x5c2a4bbb9e0375000982437a8a7326cf8495d6e7e6992779d4b66d780e04508e" },
    { tokenAddress: "0x0d668bf10b60ec9694b7cc8f6ccd52dc32f50d4bc53973c9baf7e41f34854fd5::tub::TUB", listedPoolId: "0xf48284d07667f68e089355a2374494368dd5ffc7ea1b1337280476e817ed2402" },
    { tokenAddress: "0xb81b84d91ea2dd7ded2825c999e8ee6b8ead1b23cb6b9ea475cc6e405a68609f::bloop::BLOOP", listedPoolId: "0x25e7b858615bbdf69b898b1929f46a4aee75b6831122d3a97dfb91c6a9269275" },
    { tokenAddress: "0x035d31053da220c12e196b053fe1cd20ee635001d8c81dce7a3f14e9c583713c::ballsy::BALLSY", listedPoolId: "0x9ac28369289dca759311bf4dbf82fe1b9a567b591d840536154d25023e57ace2" },
    { tokenAddress: "0x7396c4deb7e6cce3e38419563d22534f7c427786773b92d1c23751cdbae96560::wolf::WOLF", listedPoolId: "0xfeed852dfd4e96e824a7ad309dceae41adbe83ba421f07da1fd9551bc5517042" },
    { tokenAddress: "0x54899684dfecabc4bfaee3a386e8ca6048bd0af240bbde34c82a970c6552b4b9::rblz::RBLZ", listedPoolId: "0x52b0ebab0cdd9eb341fd96617eb97db54cd16bbe7e6913248d791f6c5e5785ca" },
    { tokenAddress: "0x4b70f749f11622bfc58fa7ca1ce361f995f811967f631b31f5ca979c39be9f33::mbr::MBR", listedPoolId: "0x1e88ea876090e70b997987f466de2026a2c4df1a5bda0fbc10f7404e2d11d41d" }
];

const redeem = async (tokenAddress: string, vesting_periods_index: number, listedPoolId?: string) => {
    try {
        console.log(
            `Redeeming Cetus rewards for ${tokenAddress.split("::").at(-1)} with vesting period index: ${vesting_periods_index}`
        );

        const tx = new TransactionBlock();
        tx.setGasBudget(30000000);

        const cetusRedeemVersionedId = "0x4f6f2f638362505836114f313809b834dafd58e3910df5110f6e54e4e35c929b";
        const cetusClmmVesterId = "0xe255c47472470c03bbefb1fc883459c2b978d3ad29aa8ee0c8c1ec9753fa7d01";
        
        const cetusPoolId = listedPoolId || "0x0000000000000000000000000000000000000000000000000000000000000000";

        const bondingCurveConfig = tx.object(configAddress);
        const versioned = tx.object(cetusRedeemVersionedId);
        const clmmVester = tx.object(cetusClmmVesterId);
        const cetusPool = tx.object(cetusPoolId);
        const clock = tx.object("0x6");

        tx.moveCall({
            target: `${packageAddress}::moonbags::redeem`,
            typeArguments: [tokenAddress],
            arguments: [
                bondingCurveConfig,
                versioned,
                clmmVester,
                cetusPool,
                tx.pure(vesting_periods_index),
                clock,
            ],
        });

        await processResult(tx);
    } catch (e) {
        console.error(`Error redeeming Cetus rewards for ${tokenAddress.split("::").at(-1)}:`, e);
    }
};

const redeemAll = async () => {
    const vesting_periods_index = 4;
    console.log(`Starting redemption for ${tokenData.length} tokens with vesting index ${vesting_periods_index}...`);
    
    for (let i = 0; i < tokenData.length; i++) {
        const { tokenAddress, listedPoolId } = tokenData[i];
        console.log(`\n[${i + 1}/${tokenData.length}] Processing token: ${tokenAddress.split("::").at(-1)}`);
        
        await redeem(tokenAddress, vesting_periods_index, listedPoolId);
        
        // Add a small delay between transactions to avoid rate limiting
        if (i < tokenData.length - 1) {
            console.log("Waiting 2 seconds before next transaction...");
            await new Promise(resolve => setTimeout(resolve, 2000));
        }
    }
    
    console.log("\nCompleted redemption for all tokens!");
};

const run = async () => {
    const rl = readline.createInterface({
        input: process.stdin,
        output: process.stdout,
    });

    console.log("Choose an option:");
    console.log("1. Redeem for a single token");
    console.log("2. Redeem for all tokens in the list");
    
    rl.question("Enter your choice (1 or 2): ", (choice) => {
        if (choice === "1") {
            rl.question("Enter the token address (e.g., 0x123::token::TOKEN): ", (tokenAddress) => {
                redeem(tokenAddress, 0); // Fixed vesting index to 0
                rl.close();
            });
        } else if (choice === "2") {
            redeemAll(); // No vesting index parameter needed
            rl.close();
        } else {
            console.error("Invalid choice. Please enter 1 or 2.");
            rl.close();
        }
    });
};

run();
