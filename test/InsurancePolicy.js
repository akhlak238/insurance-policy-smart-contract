const {expect} = require("chai");

describe("InsurancePolicy Contract", function(){
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

    describe("InsurancePolicy", function(){
        this.beforeEach(async function(){
            await insurancePolicy.onboardInsurer(insurer);
            const policy = await insurancePolicy.connect(insurer).issuePolicy(policyHolder.address, 1000000000, 2000000000, 5);
        });

        describe("onboardInsurer", function(){
            it("should onboard insurer", async function(){
                await insurancePolicy.onboardInsurer(policyHolder);
                expect(await insuranceStorage.getInsurer(policyHolder)).to.equal(true);
            });
        });

        describe("issuePolicy test cases", function(){
            it("should revert if issuer is not insurer/owner", async function(){
                await expect(insurancePolicy.connect(policyHolder).issuePolicy(policyHolder.address, 100, 1000, 5)).to.be.revertedWith("NotInsurer");
            });
            it("should revert if holder's address invalid", async function(){
                await expect(insurancePolicy.connect(insurer).issuePolicy(await ethers.ZeroAddress, 100, 1000, 5)).to.be.revertedWith("ZeroAddress");
            });
            it("should issue policy", async function(){
               await expect(insurancePolicy.connect(insurer).issuePolicy(policyHolder.address, 100, 1000, 5)).to.emit(insurancePolicy, "PolicyIssued").withArgs(policyHolder.address,100, 1000, 5);
            });
        });
        describe("payPremium", function(){
            it("should revert if someone else pay premium", async function(){
                const amount = await ethers.parseEther("1");
                await expect(insurancePolicy.connect(insurer).payPremium(0, {value: amount})).to.be.revertedWith("NotPolicyHolder");
            });
            it("should revert if amount is less than or equal to zero", async function(){
                const amount = ethers.parseEther("0");
                await expect(insurancePolicy.connect(policyHolder).payPremium(0, {value: amount})).to.be.revertedWith("zero value");
            });
            it("should revert if you pay amountmore than remaining premium amount", async function(){
                const amount = await ethers.parseEther("1000");
                await expect(insurancePolicy.connect(policyHolder).payPremium(0, {value: amount})).to.be.revertedWith("PremiumExceeded");
            });
            it("should emit event after paid", async function(){
                const amount = await ethers.parseEther("0.000000001");
                expect(await insurancePolicy.connect(policyHolder).payPremium(0, {value: amount})).to.emit(insurancePolicy, "PremiumPaid").withArgs(0, policyHolder.address, policyHolder.address, amount);
            });
        });
    });
});