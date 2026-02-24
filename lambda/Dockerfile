FROM public.ecr.aws/lambda/nodejs:24 AS base

FROM base AS builder

COPY ./package*.json ${LAMBDA_TASK_ROOT}

RUN npm install

COPY ./ ${LAMBDA_TASK_ROOT}

RUN npm run build

FROM base

COPY --from=builder ${LAMBDA_TASK_ROOT}/package*.json ${LAMBDA_TASK_ROOT}

RUN npm ci --only=production

COPY --from=builder ${LAMBDA_TASK_ROOT}/build ${LAMBDA_TASK_ROOT}/build

CMD [ "build/index.handler" ]
