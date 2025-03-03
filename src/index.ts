import express, { Request, Response } from "express";
import expressWs from "express-ws";
import {v4} from 'uuid';

const app = express();
const port = process.env.PORT || 3000;
const appWs = expressWs(app);

app.use(express.json());

function log(...args: any[]) {
  const timestamp = new Date().toISOString();
  console.log(`${timestamp} |`, ...args);
}

appWs.app.ws("/ws", (ws, req) => {
  const client = {
    id: v4(),
    instance: ws,
  };

  log(`${client.id}\t|`, "client connected");

  ws.on("message", (msg) => {
    log(`${client.id}\t|`, "broadcasting message |", msg.toString());
    appWs.getWss().clients.forEach((c) => {
      if (c === client.instance) {
        return
      }

      if (c.readyState === 1) {
        c.send(msg.toString());
      }
    });
  });

  ws.on("close", () => {
    log(`${client.id}\t|`, "client disconnected");
  });
});

app.get("/", (req: Request, res: Response) => {
  res.send("Hello World!");
});

app.listen(port, () => {
  log('SERVER\t\t\t\t|', 'online |', `http://localhost:${port}`);
});

export default app;
