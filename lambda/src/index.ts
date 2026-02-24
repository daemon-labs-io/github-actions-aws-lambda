import { Handler } from "aws-lambda";

export const handler: Handler = async (event, context) => {
  console.log("Hello world!");
  console.log({ event, context });

  return {
    statusCode: 200,
    body: JSON.stringify({ event, context }),
  };
};
