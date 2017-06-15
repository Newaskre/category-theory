Set Warnings "-notation-overridden".

Require Import Category.Lib.
Require Import Category.Theory.Category.

Require Import Coq.Program.Program.
Require Import Coq.Bool.Bool.
Require Import Coq.Arith.Bool_nat.
Require Import Coq.Arith.PeanoNat.
Require Import Coq.Lists.List.
Require Import Coq.Classes.Morphisms.
Require Import Coq.quote.Quote.
Require Import Coq.Wellfounded.Lexicographic_Product.
Require Import Coq.NArith.NArith.

Generalizable All Variables.

Definition obj_idx := N.
Definition arr_idx := N.

Set Universe Polymorphism.

Program Instance option_setoid `{Setoid A} : Setoid (option A) := {
  equiv := fun x y => match x, y with
    | Some x, Some y => x ≈ y
    | None, None => True
    | _, _ => False
    end
}.
Next Obligation. intuition; discriminate. Defined.
Next Obligation. intuition; discriminate. Defined.
Next Obligation.
  equivalence.
  - destruct x; reflexivity.
  - destruct x, y; auto.
    symmetry; auto.
  - destruct x, y, z; auto.
      transitivity a0; auto.
    contradiction.
Defined.

Lemma K_dec_on_type A (x : A) (eq_dec : ∀ y : A, x = y \/ x ≠ y)
      (P : x = x -> Type) :
  P (eq_refl x) -> ∀ p:x = x, P p.
Proof.
  intros.
  elim (@Eqdep_dec.eq_proofs_unicity_on A _) with x (eq_refl x) p.
    trivial.
  exact eq_dec.
Defined.

Corollary Neq_dec' : ∀ x y : N, x = y \/ x ≠ y.
Proof. intros; destruct (N.eq_dec x y); auto. Defined.

Lemma Neq_dec_refl n : N.eq_dec n n = left (@eq_refl N n).
Proof.
  destruct (N.eq_dec n n).
    refine (K_dec_on_type N n (Neq_dec' n)
              (fun x => @left _ _ x = @left _ _ (@eq_refl N n)) _ _).
    reflexivity.
  contradiction.
Defined.

Unset Universe Polymorphism.

Open Scope N_scope.

Set Decidable Equality Schemes.
Set Boolean Equality Schemes.

Inductive Term : Set :=
  | Identity : N -> Term
  | Morph    : N -> N -> N -> Term
  | Compose  : Term -> Term -> Term.

Fixpoint TermDom (e : Term) : obj_idx :=
  match e with
  | Identity x  => x
  | Morph x _ _ => x
  | Compose _ g => TermDom g
  end.

Fixpoint TermCod (e : Term) : obj_idx :=
  match e with
  | Identity x  => x
  | Morph _ x _ => x
  | Compose f _ => TermCod f
  end.

Inductive Subterm : Term -> Term -> Prop :=
  | Compose1 : ∀ t1 t2, Subterm t1 (Compose t1 t2)
  | Compose2 : ∀ t1 t2, Subterm t2 (Compose t1 t2).

Lemma Subterm_wf : well_founded Subterm.
Proof.
  constructor; intros.
  inversion H; subst; simpl in *;
  induction y;
  induction t1 || induction t2;
  simpl in *;
  constructor; intros;
  inversion H0; subst; clear H0;
  try (apply IHy1; constructor);
  try (apply IHy2; constructor).
Defined.

Section Symmetric_Product2.

Variable A : Type.
Variable leA : A -> A -> Prop.

Inductive symprod2 : A * A -> A * A -> Prop :=
  | left_sym2 :
    ∀ x x':A, leA x x' -> ∀ y:A, symprod2 (x, y) (x', y)
  | right_sym2 :
    ∀ y y':A, leA y y' -> ∀ x:A, symprod2 (x, y) (x, y')
  | both_sym2 :
    ∀ (x x':A) (y y':A),
      leA x x' ->
      leA y y' ->
      symprod2 (x, y) (x', y').

Lemma Acc_symprod2 :
  ∀ x:A, Acc leA x -> ∀ y:A, Acc leA y -> Acc symprod2 (x, y).
Proof.
  induction 1 as [x _ IHAcc]; intros y H2.
  induction H2 as [x1 H3 IHAcc1].
  apply Acc_intro; intros y H5.
  inversion_clear H5; auto with sets.
  apply IHAcc; auto.
  apply Acc_intro; trivial.
Defined.

Lemma wf_symprod2 :
  well_founded leA -> well_founded symprod2.
Proof.
  red.
  destruct a.
  apply Acc_symprod2; auto with sets.
Defined.

End Symmetric_Product2.

Definition R := symprod2 Term Subterm.
Arguments R /.

Open Scope lazy_bool_scope.

Set Transparent Obligations.

Local Obligation Tactic := intros; try discriminate.

Ltac equalities :=
  repeat match goal with
    | [ H : (_ &&& _) = true |- _ ] =>
      rewrite <- andb_lazy_alt in H
    | [ H : (_ && _) = true |- _ ] =>
      apply andb_true_iff in H;
      destruct H
    | [ H : _ /\ _ |- _ ] =>
      destruct H
    | [ H : _ ∧ _ |- _ ] =>
      destruct H
    | [ H : (_ =? _) = true |- _ ] =>
      apply N.eqb_eq in H
    end;
  simpl TermDom in *;
  simpl TermCod in *;
  subst.

Ltac forward_reason :=
  repeat match goal with
  | |- context[match ?X with left _ => _ | right _ => None end = Some _] =>
    destruct X; [| solve [ inversion 1 | inversion 2 ] ]
  | |- context[match ?X with Some _ => _ | None => None end = Some _] =>
    destruct X; [| solve [ inversion 1 | inversion 2 ] ]
  | |- context[match ?X with left _ => _ | right _ => None end = Some _] =>
    destruct X; [| solve [ inversion 1 | inversion 2 ] ]
  end.

Section denote.

Variable (C : Category).
Variable (objs : obj_idx -> C).
Variable (arrs : arr_idx -> ∀ a b : obj_idx, option (objs a ~> objs b)).

Fixpoint denote_infer dom (e : Term) :
  option { cod : _ & objs dom ~> objs cod } :=
  match e with
  | Identity t =>
    match N.eq_dec t dom with
    | left pf_dom =>
      Some (t; match pf_dom with
               | eq_refl => @id C (objs t)
               end)
    | _ => None
    end
  | Morph dom' cod' n =>
    match N.eq_dec dom' dom, arrs n dom' cod' with
    | left pf_dom, Some arr =>
      Some (cod'; match pf_dom with
                  | eq_refl => arr
                  end)
    | _ , _ => None
    end
  | Compose g f =>
    match denote_infer dom f with
    | Some (t'; farr) =>
      match denote_infer t' g with
      | Some (t''; garr) =>
        Some (t''; (garr ∘ farr))
      | _ => None
      end
    | _ => None
    end
  end.

Fixpoint denote dom cod (e : Term) :
  option (objs dom ~> objs cod) :=
  match e with
  | Identity t =>
    match N.eq_dec t dom, N.eq_dec t cod with
    | left pf_dom, left pf_cod =>
      Some (match pf_dom, pf_cod with
            | eq_refl, eq_refl => @id C (objs t)
            end)
    | _ , _ => None
    end
  | Morph dom' cod' n =>
    match N.eq_dec dom' dom, N.eq_dec cod' cod, arrs n dom' cod' with
    | left pf_dom, left pf_cod, Some arr =>
      Some (match pf_dom, pf_cod with
            | eq_refl, eq_refl => arr
            end)
    | _, _, _ => None
    end
  | Compose g f =>
    match denote dom (TermCod f) f, denote _ cod g with
    | Some farr, Some garr => Some (garr ∘ farr)
    | _ , _ => None
    end
  end.

Lemma denote_dom_cod : ∀ f dom cod f',
  denote dom cod f = Some f' ->
  TermDom f = dom /\ TermCod f = cod.
Proof.
  induction f; intros dom cod; simpl;
  try solve [ forward_reason; auto ].
  specialize (IHf2 dom (TermCod f2)).
  specialize (IHf1 (TermCod f2) cod).
  forward_reason.
  destruct (IHf1 _ eq_refl).
  destruct (IHf2 _ eq_refl).
  tauto.
Qed.

Inductive Arrow : Set :=
  | Arr : N -> N -> N -> Arrow.

Inductive ArrowList : Set :=
  | Invalid
  | IdentityOnly : N -> ArrowList
  | ArrowChain   : Arrow -> list Arrow -> ArrowList.

Fixpoint ArrowList_length (xs : ArrowList) : nat :=
  match xs with
  | Invalid => 0
  | IdentityOnly _ => 1
  | ArrowChain _ xs => 1 + length xs
  end.

Definition ArrowList_append (xs ys : ArrowList) : ArrowList :=
  match xs, ys with
  | Invalid, _ => Invalid
  | _, Invalid => Invalid
  | IdentityOnly f, IdentityOnly r =>
    if f =? r then IdentityOnly f else Invalid
  | IdentityOnly f, ArrowChain (Arr x y g) xs =>
    if f =? y then ArrowChain (Arr x y g) xs else Invalid
  | ArrowChain f xs, IdentityOnly g =>
    match last xs f with
    | Arr x y m =>
      if g =? x
      then ArrowChain f xs
      else Invalid
    end
  | ArrowChain f xs, ArrowChain (Arr z w g) ys =>
    match last xs f with
    | Arr x y m =>
      if w =? x
      then ArrowChain f (xs ++ Arr z w g :: ys)
      else Invalid
    end
  end.

Lemma ArrowList_append_chains a a0 l l0 :
  match last l a, a0 with
  | Arr x y f, Arr z w g => w = x
  end ->
  ArrowList_append (ArrowChain a l) (ArrowChain a0 l0) =
  ArrowChain a (l ++ a0 :: l0).
Proof.
  generalize dependent a0.
  generalize dependent l0.
  induction l using rev_ind; simpl; intros.
    destruct a0, a.
    subst.
    rewrite N.eqb_refl.
    reflexivity.
  simpl in H.
  destruct a0, a.
  destruct (last (l ++ [x]) (Arr n2 n3 n4)); subst.
  rewrite N.eqb_refl.
  reflexivity.
Qed.

Fixpoint normalize (p : Term) : ArrowList :=
  match p with
  | Identity x  => IdentityOnly x
  | Morph x y f => ArrowChain (Arr x y f) []
  | Compose f g => ArrowList_append (normalize f) (normalize g)
  end.

(* The list [f; g; h] maps to [f ∘ g ∘ h]. *)
Fixpoint normalize_denote dom cod (xs : ArrowList) {struct xs} :
  option (objs dom ~> objs cod) :=
  match xs with
  | Invalid => None
  | IdentityOnly x =>
    match N.eq_dec x dom, N.eq_dec x cod with
    | left Hdom, left Hcod =>
      Some (eq_rect x (fun z => objs dom ~> objs z)
                    (eq_rect x (fun z => objs z ~> objs x)
                             (@id C (objs x)) dom Hdom) cod Hcod)
    | _, _ => None
    end
  | ArrowChain f fs =>
    let fix go cod' g gs :=
        match g, gs with
        | Arr x y h, nil =>
          match arrs h x y with
          | Some p =>
            match N.eq_dec x dom, N.eq_dec y cod' with
            | left Hdom, left Hcod =>
              Some (eq_rect y (fun z => objs dom ~> objs z)
                            (eq_rect x (fun z => objs z ~> objs y)
                                     p dom Hdom) cod' Hcod)
            | _, _ => None
            end
          | _ => None
          end
        | Arr x y h, Arr z w j :: js =>
          match arrs h x y with
          | Some p =>
            match N.eq_dec y cod' with
            | left Hcod =>
              match go x (Arr z w j) js with
              | Some q =>
                Some (eq_rect y (fun y => objs dom ~> objs y)
                              (p ∘ q) cod' Hcod)
              | _ => None
              end
            | _ => None
            end
          | _ => None
          end
        end
    in go cod f fs
  end.

Goal ∀ x, normalize_denote x x (IdentityOnly x) = Some id.
  intros; simpl.
  rewrite Neq_dec_refl.
  reflexivity.
Qed.

Goal ∀ x y f, normalize_denote x y (ArrowChain (Arr x y f) nil) = arrs f x y.
  intros; simpl.
  rewrite !Neq_dec_refl.
  destruct (arrs f x y); auto.
Qed.

Goal ∀ x y z f g, normalize_denote x z (ArrowChain (Arr y z f) [Arr x y g]) =
                  match arrs f y z, arrs g x y with
                  | Some f, Some g => Some (f ∘ g)
                  | _, _ => None
                  end.
  intros; simpl.
  rewrite !Neq_dec_refl.
  destruct (arrs f y z); auto.
  destruct (arrs g x y); auto.
Qed.

Theorem normalize_chain_rule a xs dom cod :
  normalize_denote dom cod (ArrowChain a xs) = None ->
  match a with Arr x y f => y ≠ cod end \/
  let fix go h ys :=
      match h with
      | Arr x y f =>
        arrs f x y = None \/
        match ys with
        | nil => x ≠ dom
        | cons (Arr z w g) xs => w ≠ x \/ go (Arr z w g) xs
        end
      end in
  go a xs.
Proof.
  generalize dependent dom.
  generalize dependent cod.
  generalize dependent a.
  induction xs; intros.
    destruct a; simpl in *.
    destruct (arrs n1 n n0).
      destruct (N.eq_dec n dom);
      destruct (N.eq_dec n0 cod);
      subst; intuition.
    intuition.
  simpl.
  destruct a, a0.
  destruct (arrs n4 n2 n3).
    destruct (N.eq_dec n3 cod); subst.
    simpl in H.
    simpl in IHxs.
Admitted.

Theorem normalize_compose : ∀ p1 p2 dom cod f,
  normalize_denote dom cod (normalize (Compose p1 p2)) = Some f ->
  ∃ g h, f ≈ g ∘ h ∧
         normalize_denote (TermCod p2) cod (normalize p1) = Some g ∧
         normalize_denote dom (TermCod p2) (normalize p2) = Some h.
Proof.
Admitted.

Lemma normalize_dom_cod : ∀ p dom cod f,
  normalize_denote dom cod (normalize p) = Some f ->
  TermDom p = dom /\ TermCod p = cod.
Proof.
  induction p; intros.
  - simpl in *.
    destruct (N.eq_dec n cod); subst;
    destruct (N.eq_dec cod dom); subst;
    intuition; try discriminate;
    destruct (N.eq_dec n dom); subst;
    discriminate.
  - simpl in *.
    destruct (arrs n1 n n0); [|discriminate].
    destruct (N.eq_dec n dom); subst;
    destruct (N.eq_dec n0 cod); subst;
    intuition; discriminate.
  - specialize (IHp1 (TermCod p2) cod).
    specialize (IHp2 dom (TermCod p2)).
    apply normalize_compose in H.
    destruct H, s, p, p.
    destruct (IHp1 _ e0), (IHp2 _ e1);
    clear IHp1 IHp2; subst.
    intuition.
Qed.

Theorem normalize_denote_none_inv : ∀ p dom cod,
  normalize_denote dom cod (normalize p) = None ->
  match p with
  | Identity x  => dom ≠ cod \/ x ≠ dom
  | Morph x y f => dom ≠ x \/ cod ≠ y \/ arrs f x y = None
  | Compose f g =>
    normalize_denote (TermCod g) cod (normalize f) = None \/
    normalize_denote dom (TermCod g) (normalize g) = None
  end.
Proof.
  induction p; simpl; intros.
  - destruct (N.eq_dec n dom);
    destruct (N.eq_dec n cod); subst; auto; discriminate.
  - destruct (arrs n1 n n0);
    destruct (N.eq_dec n dom);
    destruct (N.eq_dec n0 cod); subst; auto.
  - admit.
Admitted.

Theorem normalize_sound : ∀ p dom cod f,
  normalize_denote dom cod (normalize p) = Some f ->
  ∃ f', f ≈ f' ∧ denote dom cod p = Some f'.
Proof.
  induction p; intros.
  - simpl in *; exists f; subst.
    split; [reflexivity|].
    destruct (N.eq_dec n dom); subst;
    destruct (N.eq_dec dom cod); subst; auto.
  - simpl in *; exists f; subst.
    split; [reflexivity|].
    destruct (N.eq_dec n dom); subst;
    destruct (N.eq_dec n0 cod); subst; auto.
    + destruct (arrs n1 dom n0); auto.
    + destruct (arrs n1 n cod); auto.
    + destruct (arrs n1 n n0); auto.
  - specialize (IHp1 (TermCod p2) cod).
    specialize (IHp2 dom (TermCod p2)).
    apply normalize_compose in H.
    destruct H, s, p, p.
    destruct (IHp1 _ e0), (IHp2 _ e1); clear IHp1 IHp2.
    exists (x1 ∘ x2).
    intuition.
    simpl.
      rewrite a, a0 in e.
      apply e.
    simpl.
    rewrite b0, b.
    reflexivity.
Qed.

Lemma normalize_complete : ∀ f dom cod,
  normalize_denote dom cod (normalize f) = None ->
  denote dom cod f = None.
Proof.
  induction f; intros.
  - simpl in *.
    destruct (N.eq_dec n dom); subst;
    destruct (N.eq_dec dom cod); subst; auto.
  - simpl in *.
    destruct (N.eq_dec n dom); subst;
    destruct (N.eq_dec n0 cod); subst; auto.
  - specialize (IHf1 (TermCod f2) cod).
    specialize (IHf2 dom (TermCod f2)).
    simpl.
    apply normalize_denote_none_inv in H.
    destruct H.
      rewrite (IHf1 H).
      destruct (denote dom (TermCod f2) f2); reflexivity.
    rewrite (IHf2 H).
    destruct (denote dom (TermCod f2) f2); reflexivity.
Qed.

Corollary normalize_to_denote : ∀ dom cod f g,
  normalize f = normalize g ->
    normalize_denote dom cod (normalize f) =
    normalize_denote dom cod (normalize g).
Proof. intros; rewrite H; reflexivity. Qed.

Theorem normalize_apply dom cod : ∀ f g,
  TermDom f = dom ->
  TermCod f = cod ->
  TermDom g = dom ->
  TermCod g = cod ->
  normalize f = normalize g ->
  denote dom cod f ≈ denote dom cod g.
Proof.
  intros.
  apply (normalize_to_denote dom cod) in H3.
  destruct (normalize_denote dom cod (normalize f)) eqn:Heqe.
    destruct (normalize_sound _ dom cod _ Heqe), p.
    destruct (normalize_denote dom cod (normalize g)) eqn:Heqe2.
      destruct (normalize_sound _ dom cod _ Heqe2), p.
      inversion H3; subst; clear H3.
      rewrite e0, e2.
      red.
      rewrite <- e, <- e1.
      reflexivity.
    discriminate.
  symmetry in H3.
  rewrite (normalize_complete _ _ _ Heqe).
  rewrite (normalize_complete _ _ _ H3).
  reflexivity.
Qed.

End denote.

Import ListNotations.

Ltac inList x xs :=
  match xs with
  | tt => false
  | (x, _) => true
  | (_, ?xs') => inList x xs'
  end.

Ltac addToList x xs :=
  let b := inList x xs in
  match b with
  | true => xs
  | false => constr:((x, xs))
  end.

Ltac allVars fs xs e :=
  match e with
  | @id _ ?x =>
    let xs := addToList x xs in
    constr:((fs, xs))
  | ?e1 ∘ ?e2 =>
    let res := allVars fs xs e1 in
    match res with
      (?fs, ?xs) => allVars fs xs e2
    end
  | ?f =>
    match type of f with
    | ?x ~> ?y =>
      let xs := addToList x xs in
      let xs := addToList y xs in
      let fs := addToList f fs in
      constr:((fs, xs))
    end
  end.

Ltac lookup x xs :=
  match xs with
  | (x, _) => constr:(0)
  | (_, ?xs') =>
    let n := lookup x xs' in
    constr:(N.succ n)
  end.

Ltac reifyTerm fs xs t :=
  match t with
  | @id _ ?X =>
    let x := lookup X xs in
    constr:(Identity x)
  | ?X1 ∘ ?X2 =>
    let r1 := reifyTerm fs xs X1 in
    let r2 := reifyTerm fs xs X2 in
    constr:(Compose r1 r2)
  | ?F =>
    let n := lookup F fs in
    match type of F with
    | ?X ~> ?Y =>
      let x := lookup X xs in
      let y := lookup Y xs in
      constr:(Morph x y n)
    end
  end.

Ltac objects_function xs :=
  let rec loop n xs' :=
    match xs' with
    | (?x, tt) => constr:(fun _ : N => x)
    | (?x, ?xs'') =>
      let f := loop (N.succ n) xs'' in
      constr:(fun m : N => if m =? n then x else f m)
    end in
  loop 0 xs.

Ltac observe n f xs objs k :=
  match type of f with
  | ?X ~> ?Y =>
    let xn := lookup X xs in
    let yn := lookup Y xs in
    constr:(fun i x y : N =>
      if i =? n
      then (match N.eq_dec xn x, N.eq_dec yn y with
            | left Hx, left Hy =>
              @Some (objs x ~> objs y)
                    (eq_rect yn (fun y => objs x ~> objs y)
                       (eq_rect xn (fun x => objs x ~> objs yn) f x Hx) y Hy)
            | _, _ => @None (objs x ~> objs y)
            end)
      else k i x y)
  end.

Ltac arrows_function fs xs objs :=
  let rec loop n fs' :=
    match fs' with
    | tt =>
      constr:(fun _ x y : N => @None (objs x ~> objs y))
    | (?f, tt) =>
      observe n f xs objs (fun _ x y : N => @None (objs x ~> objs y))
    | (?f, ?fs'') =>
      let k := loop (N.succ n) fs'' in
      observe n f xs objs k
    end in
  loop 0 fs.

Ltac categorical :=
  match goal with
  | [ |- ?S ≈ ?T ] =>
    let env := allVars tt tt S in
    match env with
      (?fs, ?xs) =>
      let env := allVars fs xs T in
      match env with
        (?fs, ?xs) =>
        pose xs;
        pose fs;
        let objs := objects_function xs in
        let arrs := arrows_function fs xs objs in
        pose objs;
        pose arrs;
        let r1  := reifyTerm fs xs S in
        let r2  := reifyTerm fs xs T in
        pose r1;
        pose r2;
        change (denote _ objs arrs (TermDom r1) (TermCod r1) r1 ≈
                denote _ objs arrs (TermDom r2) (TermCod r2) r2);
        apply (normalize_apply _ objs arrs (TermDom r1) (TermCod r1)
                 r1 r2 eq_refl eq_refl);
        vm_compute;
        auto
      end
    end
  end.

Example sample_1 :
  ∀ (C : Category) (x y z w : C) (f : z ~> w) (g : y ~> z) (h : x ~> y),
    f ∘ (id ∘ g ∘ h) ≈ (f ∘ g) ∘ h.
Proof.
  intros.
  Time categorical.
Qed.

Print Assumptions sample_1.
