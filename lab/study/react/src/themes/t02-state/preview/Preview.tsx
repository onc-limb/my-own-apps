import { IndexKeyDemo, InnerDefinitionDemo, KeyResetDemo, SamePositionDemo } from "./position";
import { ControlledInputDemo, FormPitfallsDemo, LiftingAccordionDemo, UncontrolledFormDemo } from "./controlled";
import { DerivedStateDemo, GroupedStateDemo, SelectByIdDemo, StatusUnionDemo } from "./design";
import { ReducerContextDemo, TodoReducerDemo, ThemeContextDemo } from "./reducerContext";

// ASSUMPTION: 後続テーマ（2 / 3 / 5）の本編は別途作るため、ここは「テーマ 1 から見た予習」として
// t02-state 配下に置いた。各テーマの本編を作るときに、該当セクションをそちらへ移すか参照する。
export function Theme02Preview() {
  return (
    <>
      <h1>テーマ 1-補2: state の発展（後のテーマの予習）</h1>
      <p className="note">
        解説は同じディレクトリの README.md。各カードは「NG と OK を並べて、触って差を見る」構成。
      </p>

      <h2>5. state は位置に紐づく／key でリセット（→ テーマ 2）</h2>
      <SamePositionDemo />
      <InnerDefinitionDemo />
      <KeyResetDemo />
      <IndexKeyDemo />

      <h2>6. 制御コンポーネントとリフトアップ（→ テーマ 3）</h2>
      <ControlledInputDemo />
      <UncontrolledFormDemo />
      <FormPitfallsDemo />
      <LiftingAccordionDemo />

      <h2>7. state の設計（→ テーマ 5）</h2>
      <DerivedStateDemo />
      <StatusUnionDemo />
      <SelectByIdDemo />
      <GroupedStateDemo />

      <h2>8. useReducer と Context（→ テーマ 5）</h2>
      <TodoReducerDemo />
      <ThemeContextDemo />
      <ReducerContextDemo />
    </>
  );
}
