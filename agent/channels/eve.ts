import { eveChannel } from "eve/channels/eve";
import { localDev, none } from "eve/channels/auth";

// Local repro only: accept anonymous traffic explicitly.
export default eveChannel({
  auth: [localDev(), none()],
});
