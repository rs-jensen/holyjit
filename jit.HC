U8 *g_code;
I64 g_pos;
U8 *g_src;
I64 g_ip;

U0 Emit8(U8 b) {
  g_code[g_pos++] = b;
}

U0 Emit32(I64 v) {
  I64 i;
  for (i = 0; i < 4; i++)
    Emit8((v >> (i * 8)) & 0xFF);
}

U0 Emit64(I64 v) {
  I64 i;
  for (i = 0; i < 8; i++)
    Emit8((v >> (i * 8)) & 0xFF);
}

U0 Patch32(I64 pos, I64 v) {
  I64 i;
  for (i = 0; i < 4; i++)
    g_code[pos + i] = (v >> (i * 8)) & 0xFF;
}

U0 SkipSpace() {
  while (g_src[g_ip] == ' ') g_ip++;
}

Bool Match(U8 *kw) {
  I64 i = 0;
  while (kw[i]) {
    if (g_src[g_ip + i] != kw[i]) return FALSE;
    i++;
  }
  return TRUE;
}

I64 ParseNum() {
  I64 v = 0;
  while (g_src[g_ip] >= '0' && g_src[g_ip] <= '9') {
    v = v * 10 + (g_src[g_ip] - '0');
    g_ip++;
  }
  return v;
}

U0 CompileRel();

U0 CompileFactor() {
  U8 c;
  SkipSpace();
  c = g_src[g_ip];
  if (c == '(') {
    g_ip++;
    CompileRel();
    SkipSpace();
    g_ip++;
  } else if (c == '-') {
    g_ip++;
    CompileFactor();
    Emit8(0x48); Emit8(0xF7); Emit8(0xD8);
  } else if (c >= 'a' && c <= 'z') {
    g_ip++;
    Emit8(0x48); Emit8(0x8B); Emit8(0x87);
    Emit32((c - 'a') * 8);
  } else {
    Emit8(0x48); Emit8(0xB8);
    Emit64(ParseNum());
  }
}

U0 CompileTerm() {
  U8 op;
  CompileFactor();
  SkipSpace();
  while (g_src[g_ip] == '*' || g_src[g_ip] == '/') {
    op = g_src[g_ip++];
    Emit8(0x50);
    CompileFactor();
    Emit8(0x5B);
    if (op == '*') {
      Emit8(0x48); Emit8(0x0F); Emit8(0xAF); Emit8(0xC3);
    } else {
      Emit8(0x48); Emit8(0x89); Emit8(0xC1);
      Emit8(0x48); Emit8(0x89); Emit8(0xD8);
      Emit8(0x48); Emit8(0x99);
      Emit8(0x48); Emit8(0xF7); Emit8(0xF9);
    }
    SkipSpace();
  }
}

U0 CompileExpr() {
  U8 op;
  CompileTerm();
  SkipSpace();
  while (g_src[g_ip] == '+' || g_src[g_ip] == '-') {
    op = g_src[g_ip++];
    Emit8(0x50);
    CompileTerm();
    Emit8(0x5B);
    if (op == '+') {
      Emit8(0x48); Emit8(0x01); Emit8(0xD8);
    } else {
      Emit8(0x48); Emit8(0x29); Emit8(0xC3);
      Emit8(0x48); Emit8(0x89); Emit8(0xD8);
    }
    SkipSpace();
  }
}

U0 CompileRel() {
  U8 op;
  CompileExpr();
  SkipSpace();
  if (g_src[g_ip] == '<' || g_src[g_ip] == '>' ||
      (g_src[g_ip] == '=' && g_src[g_ip + 1] == '=')) {
    if (g_src[g_ip] == '=') {
      op = '=';
      g_ip += 2;
    } else {
      op = g_src[g_ip];
      g_ip++;
    }
    Emit8(0x50);
    CompileExpr();
    Emit8(0x5B);
    Emit8(0x48); Emit8(0x39); Emit8(0xC3);
    if (op == '<') {
      Emit8(0x0F); Emit8(0x9C); Emit8(0xC0);
    } else if (op == '>') {
      Emit8(0x0F); Emit8(0x9F); Emit8(0xC0);
    } else {
      Emit8(0x0F); Emit8(0x94); Emit8(0xC0);
    }
    Emit8(0x48); Emit8(0x0F); Emit8(0xB6); Emit8(0xC0);
  }
}

U0 HostPrint(I64 v) {
  Print("%d\n", v);
}

U0 CompileProgram();

U0 CompileAssign() {
  U8 v;
  SkipSpace();
  v = g_src[g_ip++];
  SkipSpace();
  g_ip++;
  CompileRel();
  Emit8(0x48); Emit8(0x89); Emit8(0x87);
  Emit32((v - 'a') * 8);
}

U0 CompilePrint() {
  g_ip += 5;
  CompileRel();
  Emit8(0x48); Emit8(0x89); Emit8(0xC7);
  Emit8(0x48); Emit8(0xB8);
  Emit64(&HostPrint);
  Emit8(0xFF); Emit8(0xD0);
}

U0 CompileWhile() {
  I64 loop_start, jz_pos, loop_end;
  g_ip += 5;
  SkipSpace();
  g_ip++;
  loop_start = g_pos;
  CompileRel();
  SkipSpace();
  g_ip++;
  Emit8(0x48); Emit8(0x85); Emit8(0xC0);
  Emit8(0x0F); Emit8(0x84);
  jz_pos = g_pos;
  Emit32(0);
  SkipSpace();
  g_ip++;
  CompileProgram();
  SkipSpace();
  g_ip++;
  Emit8(0xE9);
  Emit32(loop_start - (g_pos + 4));
  loop_end = g_pos;
  Patch32(jz_pos, loop_end - (jz_pos + 4));
}

U0 CompileStmt() {
  SkipSpace();
  if (Match("while")) CompileWhile();
  else if (Match("print")) CompilePrint();
  else CompileAssign();
}

U0 CompileProgram() {
  CompileStmt();
  SkipSpace();
  while (g_src[g_ip] == ';') {
    g_ip++;
    SkipSpace();
    if (g_src[g_ip] == 0 || g_src[g_ip] == '}') break;
    CompileStmt();
    SkipSpace();
  }
}

U0 Run(U8 *src) {
  I64 vars[26];
  U0 (*fn)(I64 *);
  I64 i;
  for (i = 0; i < 26; i++) vars[i] = 0;
  g_code = CAlloc(4096);
  g_pos = 0;
  g_src = src;
  g_ip = 0;
  CompileProgram();
  Emit8(0xC3);
  fn = g_code;
  fn(vars);
  Free(g_code);
}

U0 Main() {
  Run("a=1;i=1;while(i<11){a=a*i;print a;i=i+1}");
  Run("x=7;print x*x+1");
  Run("f0=0;f1=1;n=0;while(n<10){print f0;t=f0+f1;f0=f1;f1=t;n=n+1}");
}

Main;
