import { Test, TestingModule } from "@nestjs/testing";
import { PortalController } from "./portal.controller";
import { describe, expect, it, jest, beforeEach } from "@jest/globals";

describe("PortalController", () => {
  let controller: PortalController;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [PortalController],
    }).compile();

    controller = module.get<PortalController>(PortalController);
  });

  it("should be defined", () => {
    expect(controller).toBeDefined();
  });

  it("should render landing page html when requested by browser", () => {
    let sentBody = "";
    let contentType = "";

    const mockReq: any = {
      accepts: (type: string) => type === "html",
      headers: {},
      query: {},
    };

    const mockRes: any = {
      setHeader: (name: string, value: string) => {
        if (name.toLowerCase() === "content-type") contentType = value;
      },
      send: (body: string) => {
        sentBody = body;
        return mockRes;
      },
      json: (data: any) => data,
    };

    controller.getRoot(mockReq, mockRes);
    expect(contentType).toContain("text/html");
    expect(sentBody).toContain("GhostRoom");
    expect(sentBody).toContain("Ephemeral Store-and-Forward");
    expect(sentBody).toContain("/download");
  });

  it("should render download portal html", () => {
    let sentBody = "";
    let contentType = "";

    const mockReq: any = {};
    const mockRes: any = {
      setHeader: (name: string, value: string) => {
        if (name.toLowerCase() === "content-type") contentType = value;
      },
      send: (body: string) => {
        sentBody = body;
        return mockRes;
      },
    };

    controller.getDownloadPortal(mockReq, mockRes);
    expect(contentType).toContain("text/html");
    expect(sentBody).toContain("Release Distribution");
    expect(sentBody).toContain("ghostroom-android.apk");
    expect(sentBody).toContain("SHA-256");
  });

  it("should render smart redirect for /connect/:publicId", () => {
    let sentBody = "";
    let contentType = "";

    const mockRes: any = {
      setHeader: (name: string, value: string) => {
        if (name.toLowerCase() === "content-type") contentType = value;
      },
      send: (body: string) => {
        sentBody = body;
        return mockRes;
      },
    };

    controller.getConnectRedirect("TEST_PUBLIC_ID_123", mockRes);
    expect(contentType).toContain("text/html");
    expect(sentBody).toContain("ghostroom://connect/TEST_PUBLIC_ID_123");
    expect(sentBody).toContain("TEST_PUBLIC_ID_123");
    expect(sentBody).toContain("1500");
  });

  it("should return android assetlinks json", () => {
    let returnedJson: any = null;
    const mockRes: any = {
      setHeader: (jest.fn() as any),
      json: (data: any) => {
        returnedJson = data;
        return data;
      },
    };

    controller.getAssetLinks(mockRes);
    expect(returnedJson).toBeDefined();
    expect(returnedJson[0].target.package_name).toBe("com.ghostroom.app");
  });

  it("should return apple app site association json", () => {
    let returnedJson: any = null;
    const mockRes: any = {
      setHeader: (jest.fn() as any),
      json: (data: any) => {
        returnedJson = data;
        return data;
      },
    };

    controller.getAppleAppSiteAssociation(mockRes);
    expect(returnedJson).toBeDefined();
    expect(returnedJson.applinks.details[0].paths).toContain("/connect/*");
  });
});
