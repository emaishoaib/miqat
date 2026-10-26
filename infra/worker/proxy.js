export default {
  async fetch(request, env) {
    const incoming = new URL(request.url);
    const target = new URL(incoming.pathname + incoming.search, env.UPSTREAM);
    return fetch(new Request(target, request));
  },
};
