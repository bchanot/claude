import { Ratelimit } from "@upstash/ratelimit";

export const limiter = new Ratelimit({
  limiter: Ratelimit.slidingWindow(10, "10 s"),
});
