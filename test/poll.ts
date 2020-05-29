import { Client, Provider, ProviderRegistry, Result, Receipt } from "@blockstack/clarity";
import { assert } from "chai";
describe("Contract test suite", () => {
  let client: Client;
  let provider: Provider;
  before(async () => {
    provider = await ProviderRegistry.createProvider();
    client = new Client("SP3GWX3NE58KXHESRYE4DYQ1S31PQJTCRXB3PE9SB.poll", "poll", provider);
  });
  it("should have a valid syntax", async () => {
    await client.checkContract();
    await client.deployContract();
  });
  const execQuery = async (method: string, args: string[]) => {
    const query = client.createQuery({
      method: { name: method, args: args }
    });
    const receipt = await client.submitQuery(query);
    return receipt;
  }
  const execMethod = async (method: string, args: string[]) => {
    const tx = client.createTransaction({
      method: {
        name: method,
        args: args,
      },
    });
    await tx.sign(signature);
    const receipt = await client.submitTransaction(tx);
    return receipt;
  }
  const assertError = (receipt: Receipt, code: number) => {
    assert.isTrue(new String(receipt.error).includes("Aborted: " + code));
  }
  const signature = "SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7";  
  const invalidSignature = "SP1FXTNRCXQW7CNKKRXZQZPZPKKVPAZS6JYX25YP5";  
  const pollStarted = 1;
  const pollWithoutOptions = 2;
  const voteInvalid = 3;
  const pollNotStarted = 4;
  const alreadyVoted = 5;

  describe("when no poll is active", () => {
    before(async () => {
      
    });   
    it("should not allow to end the poll", async () => {
      const receipt = await execMethod("end-poll", []);
      assertError(receipt, pollNotStarted);
    })
    it("should not start it unless there are at least two options", async () => {
      const receipt = await execMethod("start-poll", []);
      assertError(receipt, pollWithoutOptions);
    })
    it("should not allow to vote", async () => {
      const receipt = await execMethod("vote", [`'${signature}`, "1"]);
      assertError(receipt, pollNotStarted);
    })
    it("should allow to add a new options", async () => {
      const receipt1 = await execMethod("add-option", ["\"option1\""]);
      const receipt2 = await execMethod("add-option", ["\"option2\""]);
      assert.equal(receipt1.success, true);
      assert.equal(receipt2.success, true);
    })
    it("afterwards should allow to start the poll", async () => {
      const receipt = await execMethod("start-poll", []);
      assert.equal(receipt.success, true);
    })
  });
  describe("when new poll has started", () => {
    before(async () => {
      
    }); 
    it("should not allow to add a new option", async () => {
      const receipt = await execMethod("add-option", ["\"option1\""]);
      assertError(receipt, pollStarted);
    })
    it("should not allow to vote for non existing option", async () => {
      const receipt = await execMethod("vote", [`'${signature}`, "4"]);
      assertError(receipt, voteInvalid);
    })  
    it("should not allow to vote for non existing poll", async () => {
      const receipt = await execMethod("vote", [`'${invalidSignature}`, "1"]);
      assertError(receipt, pollNotStarted);
    })
    it("allows to vote", async () => {
      const receipt = await execMethod("vote", [`'${signature}`, "1"]);
      assert.equal(receipt.success, true);
    })  
    it("does not allow to vote second time", async () => {
      const receipt = await execMethod("vote", [`'${signature}`, "2"]);
      assertError(receipt, alreadyVoted);
    })
    it("allows to get result", async () => {
      const receipt = await execQuery("get-result", [`'${signature}`, "1"]);
      assert.equal(receipt.success, true);
    })    
    it("displays correct amount of votes", async () => {
      const receipt = await execQuery("get-result", [`'${signature}`, "1"]);
      assert.equal(Result.unwrapInt(receipt), 1);
      const receiptForSecondOpt = await execQuery("get-result", [`'${signature}`, "2"]);
      assert.equal(Result.unwrapInt(receiptForSecondOpt), 0);
    })    
    it("allows to end the poll", async () => {
      const receipt = await execMethod("end-poll", []);
      assert.equal(receipt.success, true);
    })
  });
  describe("when the poll has ended", () => {
    before(async () => {
      
    });
    it("allows to get result", async () => {
      const receipt = await execQuery("get-result", [`'${signature}`, "1"]);
      assert.equal(receipt.success, true);
    })    
    it("displays correct amount of votes", async () => {
      const receipt = await execQuery("get-result", [`'${signature}`, "1"]);
      assert.equal(Result.unwrapInt(receipt), 1);
      const receiptForSecondOpt = await execQuery("get-result", [`'${signature}`, "2"]);
      assert.equal(Result.unwrapInt(receiptForSecondOpt), 0);
    })    
    it("should not allow to vote", async () => {
      const receipt = await execMethod("vote", [`'${signature}`, "1"]);
      assertError(receipt, pollNotStarted);
    })
  });
  after(async () => {
    await provider.close();
  });
});