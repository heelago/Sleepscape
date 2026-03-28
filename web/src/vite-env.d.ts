/// <reference types="vite/client" />

declare module '*.vert.glsl' {
  const value: string;
  export default value;
}

declare module '*.frag.glsl' {
  const value: string;
  export default value;
}
