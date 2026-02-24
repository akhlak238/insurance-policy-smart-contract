const {expect} = require("chai");

describe("DrugLogistic Contract", function(){
    let insuranceStorage;
    let insurancePolicy;
    let owner;
    let insurer;
    let policyHolder;

    this.beforeEach(async function(){
        [owner, insurer, policyHolder] = await ethers.getSigners();
        const policyStorage = await ethers.getContractFactory("InsuranceStorage");
        const policyLogic = await ethers.getContractFactory("InsurancePolicy");

        insuranceStorage = await policyStorage.deploy();
        insurancePolicy = await policyLogic.deploy(await insuranceStorage.getAddress());
        await insuranceStorage.setPolicyContract(await insurancePolicy.getAddress());
    });
    describe("InsuranceStorage constructor", function(){
        it("should set deployer as owner", async function(){
            expect(await insuranceStorage.owner()).to.equal(owner.address);
        });
    });
    describe("InsurancePolicy constructor", function(){
        it("should set pharmaStorage", async function(){
            expect(await insurancePolicy.policyStorage()).to.equal(await insuranceStorage.getAddress());
        });
    });
});